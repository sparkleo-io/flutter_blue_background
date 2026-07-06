/// Android `ScanSettings` scan mode. Controls the power/latency trade-off of
/// the scan. Ignored on iOS (iOS does not expose a scan mode).
enum AndroidScanMode {
  /// Passive mode: only reports results from scans triggered by other apps.
  /// Lowest power. Native value `-1`.
  opportunistic(-1),

  /// Lowest active-scan power, longest latency. Native value `0`.
  lowPower(0),

  /// Balance between power and latency. Native value `1`.
  balanced(1),

  /// Highest power, lowest latency. Best while the app is in the foreground.
  /// Native value `2`.
  lowLatency(2);

  const AndroidScanMode(this.nativeValue);
  final int nativeValue;
}

/// Android `ScanSettings` callback type.
enum AndroidCallbackType {
  /// Report every matching advertisement. Native value `1`.
  allMatches(1),

  /// Report only the first advertisement per matching device (requires
  /// hardware batching / offloaded filtering). Native value `2`.
  firstMatch(2),

  /// Report when a previously seen device is no longer detected. Native value
  /// `4`.
  matchLost(4);

  const AndroidCallbackType(this.nativeValue);
  final int nativeValue;
}

/// Android `ScanSettings` match mode (only used with offloaded filtering).
enum AndroidMatchMode {
  /// Match quickly, even with few/weak advertisements. Native value `1`.
  aggressive(1),

  /// Require stronger/more consistent signal before matching. Native value `2`.
  sticky(2);

  const AndroidMatchMode(this.nativeValue);
  final int nativeValue;
}

/// Android `ScanSettings` number of matches (only used with offloaded
/// filtering).
enum AndroidNumOfMatches {
  /// At most one advertisement per filter. Native value `1`.
  one(1),

  /// A few advertisements per filter. Native value `2`.
  few(2),

  /// As many advertisements as hardware allows. Native value `3`.
  max(3);

  const AndroidNumOfMatches(this.nativeValue);
  final int nativeValue;
}

/// Android Bluetooth PHY used for scanning (API 26+).
enum AndroidScanPhy {
  /// 1M PHY. Native value `1`.
  le1m(1),

  /// Coded PHY (long range). Native value `3`.
  leCoded(3),

  /// All supported PHYs. Native value `255`.
  allSupported(255);

  const AndroidScanPhy(this.nativeValue);
  final int nativeValue;
}

/// Android-only scan tuning. Maps onto `android.bluetooth.le.ScanSettings`.
///
/// All of these are ignored on iOS.
class AndroidScanSettings {
  const AndroidScanSettings({
    this.scanMode = AndroidScanMode.lowLatency,
    this.callbackType = AndroidCallbackType.allMatches,
    this.matchMode,
    this.numOfMatches,
    this.legacy,
    this.phy,
  });

  final AndroidScanMode scanMode;
  final AndroidCallbackType callbackType;

  /// Only applied when offloaded filtering is used (API 23+).
  final AndroidMatchMode? matchMode;

  /// Only applied when offloaded filtering is used (API 23+).
  final AndroidNumOfMatches? numOfMatches;

  /// Whether to only report legacy (non-extended) advertisements (API 26+).
  final bool? legacy;

  /// Preferred scanning PHY (API 26+).
  final AndroidScanPhy? phy;

  Map<String, dynamic> toMap() => {
        'scanMode': scanMode.nativeValue,
        'callbackType': callbackType.nativeValue,
        if (matchMode != null) 'matchMode': matchMode!.nativeValue,
        if (numOfMatches != null) 'numOfMatches': numOfMatches!.nativeValue,
        if (legacy != null) 'legacy': legacy,
        if (phy != null) 'phy': phy!.nativeValue,
      };
}

/// iOS-only scan options. Maps onto the `CBCentralManager` scan options.
///
/// All of these are ignored on Android.
class IosScanOptions {
  const IosScanOptions({
    this.allowDuplicates = false,
    this.solicitedServiceUuids = const [],
  });

  /// `CBCentralManagerScanOptionAllowDuplicatesKey`.
  ///
  /// When true, the same peripheral can be reported repeatedly while in the
  /// foreground. Note: iOS ignores this while the app is in the background
  /// (one event per device).
  final bool allowDuplicates;

  /// `CBCentralManagerScanOptionSolicitedServiceUUIDsKey`.
  final List<String> solicitedServiceUuids;

  Map<String, dynamic> toMap() => {
        'allowDuplicates': allowDuplicates,
        'solicitedServiceUuids': solicitedServiceUuids,
      };
}

/// Configuration for a BLE scan.
///
/// The cross-platform fields ([serviceUuids], [nameFilter], [rssiThreshold])
/// apply on both platforms. Platform-specific tuning lives in [android] and
/// [ios].
///
/// Background scanning notes:
/// - iOS only delivers background discoveries for peripherals that advertise
///   one of [serviceUuids]. Leave it empty only for foreground "find anything"
///   scans.
/// - Android does not require [serviceUuids] but filtering reduces battery use
///   and improves reliability when the screen is off.
class ScanConfig {
  const ScanConfig({
    this.serviceUuids = const [],
    this.nameFilter,
    this.skipUnnamedDevices = false,
    this.rssiThreshold,
    this.reportDelay,
    this.timeout,
    this.android = const AndroidScanSettings(),
    this.ios = const IosScanOptions(),
  });

  /// Service UUID filter applied natively where supported.
  final List<String> serviceUuids;

  /// Case-insensitive substring match against the advertised device name.
  ///
  /// Applied as a client-side filter on both platforms so behaviour is
  /// identical (Android can also filter by exact name natively, but a
  /// substring match is more useful and consistent here).
  final String? nameFilter;

  /// When true, devices without an advertised local name in the BLE
  /// advertisement packet are dropped before being delivered on the results
  /// stream. Applied client-side on both platforms.
  ///
  /// This matches `flutter_blue_plus` `advName` semantics: bonded/cached
  /// platform names (e.g. Android `"Unknown"`) do **not** count as an advertised
  /// name. Only the local name in the scan response/advertisement does.
  final bool skipUnnamedDevices;

  /// Drop results with an RSSI weaker than this threshold (in dBm). Applied
  /// client-side on both platforms. Example: `-80`.
  final int? rssiThreshold;

  /// Android batch/report delay. When set (> 0), Android batches results and
  /// reports them on this interval. Ignored on iOS.
  final Duration? reportDelay;

  /// Optional scan duration. When null, the scan runs until [stopScan] is
  /// called. When set, the scan automatically stops after this duration and
  /// `isScanning` becomes false. Applies on both platforms.
  final Duration? timeout;

  /// Android-only scan tuning.
  final AndroidScanSettings android;

  /// iOS-only scan options.
  final IosScanOptions ios;

  Map<String, dynamic> toMap() => {
        'serviceUuids': serviceUuids,
        'nameFilter': nameFilter,
        'skipUnnamedDevices': skipUnnamedDevices,
        'rssiThreshold': rssiThreshold,
        'reportDelayMillis': reportDelay?.inMilliseconds,
        'timeoutMillis': timeout?.inMilliseconds,
        'android': android.toMap(),
        'ios': ios.toMap(),
      };
}
