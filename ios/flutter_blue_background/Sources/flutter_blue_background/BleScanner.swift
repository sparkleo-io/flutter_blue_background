import CoreBluetooth
import Flutter
import Foundation

/// Owns a `CBCentralManager` and translates a Dart `ScanConfig` map into a
/// CoreBluetooth scan, emitting discovered peripherals onto a Flutter
/// `EventChannel`.
///
/// CoreBluetooth only filters natively by service UUID. The remaining
/// cross-platform filters (`nameFilter` substring match and `rssiThreshold`)
/// are applied client-side in `didDiscover` so behaviour matches Android.
///
/// Unlike Android — where the scanner lives in a foreground service — iOS has no
/// equivalent. Background BLE execution relies on the `bluetooth-central`
/// UIBackgroundMode keeping this plugin-owned `CBCentralManager` alive while the
/// app is backgrounded (a force-quit still tears it down). Discovered devices
/// are cached so `getScanResults()` works after the UI returns to foreground.
class BleScanner: NSObject {

    private static let maxCacheSize = 256
    static let queueKey = DispatchSpecificKey<UInt8>()
    private static let queueKeyValue: UInt8 = 1

    /// Serial queue for all CoreBluetooth central/peripheral work.
    let bleQueue = DispatchQueue(label: "com.sparkleo.flutter_blue_background.ble", qos: .userInitiated)

    private var centralManager: CBCentralManager!
    private var eventSink: FlutterEventSink?
    private var adapterStateSink: FlutterEventSink?

    private(set) var isScanning = false

    /// Forwards central-manager connection callbacks to the connector.
    weak var connector: BleConnector?

    // Latest advertisement per deviceId; preserves discovery order.
    private var cache: [String: [String: Any]] = [:]
    private var cacheOrder: [String] = []

    /// Retained peripheral handles keyed by deviceId for subsequent connections.
    private var peripheralCache: [String: CBPeripheral] = [:]

    // Pending scan parameters, applied once the central manager powers on.
    private var pendingServiceUuids: [CBUUID]?
    private var pendingOptions: [String: Any]?
    private var hasPendingScan = false
    private var pendingTimeoutMillis: Int?
    private var timeoutTimer: Timer?

    // Client-side filters.
    private var nameFilter: String?
    private var skipUnnamedDevices = false
    private var rssiThreshold: Int?

    override init() {
        super.init()
        bleQueue.setSpecific(key: Self.queueKey, value: Self.queueKeyValue)
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)
    }

    func performOnBleQueue<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: Self.queueKey) != nil {
            return work()
        }
        return bleQueue.sync(execute: work)
    }

    deinit {
        cancelTimeoutTimer()
        if centralManager?.isScanning == true {
            centralManager.stopScan()
        }
        centralManager?.delegate = nil
        eventSink = nil
        adapterStateSink = nil
    }

    // MARK: - Public API

    func startScan(_ config: [String: Any]) -> Bool {
        performOnBleQueue { startScanOnBleQueue(config) }
    }

    private func startScanOnBleQueue(_ config: [String: Any]) -> Bool {
        let serviceUuidStrings = (config["serviceUuids"] as? [String]) ?? []
        pendingServiceUuids = serviceUuidStrings.isEmpty
            ? nil
            : serviceUuidStrings.compactMap { CBUUID(string: $0) }

        nameFilter = (config["nameFilter"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        skipUnnamedDevices = (config["skipUnnamedDevices"] as? Bool) ?? false
        rssiThreshold = config["rssiThreshold"] as? Int
        pendingTimeoutMillis = config["timeoutMillis"] as? Int

        clearCache()

        var options: [String: Any] = [:]
        if let ios = config["ios"] as? [String: Any] {
            if let allowDuplicates = ios["allowDuplicates"] as? Bool {
                options[CBCentralManagerScanOptionAllowDuplicatesKey] = allowDuplicates
            }
            if let solicited = ios["solicitedServiceUuids"] as? [String], !solicited.isEmpty {
                options[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] =
                    solicited.compactMap { CBUUID(string: $0) }
            }
        }
        pendingOptions = options

        // Restart cleanly if already scanning.
        if centralManager.isScanning {
            centralManager.stopScan()
        }

        switch centralManager.state {
        case .unsupported, .unauthorized:
            return false
        case .poweredOn:
            beginScan()
            return true
        default:
            // Defer until the central manager powers on.
            hasPendingScan = true
            FbbLog.info("Bluetooth not powered on yet; scan deferred")
            return true
        }
    }

    func stopScan() -> Bool {
        performOnBleQueue { stopScanOnBleQueue() }
    }

    private func stopScanOnBleQueue() -> Bool {
        FbbLog.debug("stopScan")
        hasPendingScan = false
        cancelTimeoutTimer()
        if centralManager.isScanning {
            centralManager.stopScan()
        }
        isScanning = false
        nameFilter = nil
        skipUnnamedDevices = false
        rssiThreshold = nil
        pendingTimeoutMillis = nil
        return true
    }

    func dispose() {
        _ = stopScan()
        detachSink()
        clearCache()
    }

    /// Detaches the Flutter event sink without stopping an active scan. Used when
    /// the engine is torn down but background scanning should continue.
    func detachSink() {
        eventSink = nil
    }

    func setAdapterStateSink(_ sink: @escaping FlutterEventSink) {
        adapterStateSink = sink
        let state = performOnBleQueue { mapAdapterState(centralManager.state) }
        sink(state)
    }

    func detachAdapterStateSink() {
        adapterStateSink = nil
    }

    func getAdapterState() -> String {
        performOnBleQueue { mapAdapterState(centralManager.state) }
    }

    func isAdapterReady() -> Bool {
        performOnBleQueue { centralManager.state == .poweredOn }
    }

    private func emitAdapterState() {
        let state = mapAdapterState(centralManager.state)
        DispatchQueue.main.async { [weak self] in
            self?.adapterStateSink?(state)
        }
    }

    private func mapAdapterState(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn:
            return "on"
        case .poweredOff:
            return "off"
        case .resetting:
            return "turningOn"
        case .unauthorized:
            return "unauthorized"
        case .unsupported:
            return "unsupported"
        case .unknown:
            return "unknown"
        @unknown default:
            return "unknown"
        }
    }

    /// Cached snapshot of devices discovered during the current/last scan.
    func getScanResults() -> [[String: Any]] {
        return cacheOrder.compactMap { cache[$0] }
    }

    func clearCache() {
        cache.removeAll()
        cacheOrder.removeAll()
    }

    /// Returns a retained `CBPeripheral` for [deviceId], if discovered or retrieved.
    func peripheral(for deviceId: String) -> CBPeripheral? {
        performOnBleQueue { peripheralOnBleQueue(for: deviceId) }
    }

    func peripheralOnBleQueue(for deviceId: String) -> CBPeripheral? {
        if let cached = peripheralCache[deviceId] {
            return cached
        }
        guard let uuid = UUID(uuidString: deviceId) else { return nil }
        return centralManager.retrievePeripherals(withIdentifiers: [uuid]).first
    }

    var sharedCentralManager: CBCentralManager {
        centralManager
    }

    // MARK: - Internal

    private func cacheResult(_ id: String, _ payload: [String: Any]) {
        if cache[id] == nil {
            cacheOrder.append(id)
        }
        cache[id] = payload
        while cacheOrder.count > Self.maxCacheSize {
            let evicted = cacheOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }

    private func beginScan() {
        centralManager.scanForPeripherals(
            withServices: pendingServiceUuids,
            options: pendingOptions
        )
        isScanning = true
        hasPendingScan = false
        scheduleTimeoutTimer()
        FbbLog.debug("Scan started")
    }

    private func scheduleTimeoutTimer() {
        cancelTimeoutTimer()
        guard let millis = pendingTimeoutMillis, millis > 0 else { return }
        let interval = TimeInterval(millis) / 1000.0
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] firedTimer in
            // Dispose the one-shot timer immediately so it never lingers,
            // regardless of what stopScan() does next.
            firedTimer.invalidate()
            guard let self = self else { return }
            if self.timeoutTimer === firedTimer {
                self.timeoutTimer = nil
            }
            FbbLog.debug("Scan timeout reached; stopping scan")
            _ = self.stopScan()
        }
        // Add explicitly to the main run loop so it fires even if created off the
        // main thread.
        RunLoop.main.add(timer, forMode: .common)
        timeoutTimer = timer
    }

    private func cancelTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
}

// MARK: - CBCentralManagerDelegate

extension BleScanner: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        emitAdapterState()
        if central.state == .poweredOn, hasPendingScan {
            beginScan()
        } else if central.state != .poweredOn {
            isScanning = false
            hasPendingScan = false
            cancelTimeoutTimer()
            if central.isScanning {
                central.stopScan()
            }
            connector?.onBluetoothAdapterOff()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssi = RSSI.intValue
        FbbLog.verbose("didDiscover: \(peripheral.identifier.uuidString) rssi=\(rssi)")

        // Client-side RSSI threshold. 127 means "unknown" per CoreBluetooth.
        if let threshold = rssiThreshold, rssi != 127, rssi < threshold {
            return
        }

        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let advName = BleNameUtils.normalizeAdvertisedName(localName)
        let platformName = BleNameUtils.normalizePlatformName(peripheral.name)

        // skipUnnamedDevices filters on advertisement local name only — not a
        // cached peripheral.name that iOS may retain from a prior connection.
        if skipUnnamedDevices, advName == nil {
            return
        }

        let nameForFilter = advName ?? platformName
        if let filter = nameFilter {
            guard let name = nameForFilter,
                  name.range(of: filter, options: .caseInsensitive) != nil else {
                return
            }
        }

        var payload: [String: Any] = [
            "deviceId": peripheral.identifier.uuidString,
            "advName": advName ?? "",
            "platformName": platformName ?? "",
            "rssi": rssi,
            "timestampMillis": Int(Date().timeIntervalSince1970 * 1000),
        ]

        if let displayName = advName ?? platformName {
            payload["name"] = displayName
        }

        if let txPower = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            payload["txPowerLevel"] = txPower.intValue
        }

        if let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber {
            payload["connectable"] = connectable.boolValue
        }

        if let mfrData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            payload["manufacturerData"] = FlutterStandardTypedData(bytes: mfrData)
        }

        if let serviceUuids = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            payload["serviceUuids"] = serviceUuids.map { $0.uuidString.lowercased() }
        }

        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            var mapped: [String: FlutterStandardTypedData] = [:]
            for (uuid, data) in serviceData {
                mapped[uuid.uuidString.lowercased()] = FlutterStandardTypedData(bytes: data)
            }
            payload["serviceData"] = mapped
        }

        cacheResult(peripheral.identifier.uuidString, payload)
        peripheralCache[peripheral.identifier.uuidString] = peripheral
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(payload)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connector?.handleDidConnect(peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connector?.handleDidFailToConnect(peripheral, error: error)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        connector?.handleDidDisconnect(peripheral, error: error)
    }
}

// MARK: - FlutterStreamHandler

extension BleScanner: FlutterStreamHandler {
    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events
        // Replay cached results so a freshly attached listener catches up on
        // devices discovered while it was not listening.
        for payload in getScanResults() {
            events(payload)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        detachSink()
        return nil
    }
}
