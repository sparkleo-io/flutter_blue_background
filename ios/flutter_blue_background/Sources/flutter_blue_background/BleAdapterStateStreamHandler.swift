import Flutter
import Foundation

/// Bridges [BleScanner] adapter state updates to a Flutter [EventChannel].
final class BleAdapterStateStreamHandler: NSObject, FlutterStreamHandler {
    private weak var scanner: BleScanner?

    init(scanner: BleScanner) {
        self.scanner = scanner
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        scanner?.setAdapterStateSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        scanner?.detachAdapterStateSink()
        return nil
    }
}
