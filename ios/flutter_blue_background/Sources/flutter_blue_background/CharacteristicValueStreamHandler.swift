import Flutter

final class CharacteristicValueStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        CharacteristicValueDispatcher.setSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        CharacteristicValueDispatcher.setSink(nil)
        return nil
    }
}
