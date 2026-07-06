import Foundation
import Flutter

enum CharacteristicValueDispatcher {
    private static let maxCache = 64
    private static var cache: [[String: Any]] = []
    private static var eventSink: FlutterEventSink?
    private static var sinkGeneration = 0

    static func setSink(_ sink: FlutterEventSink?) {
        if sink == nil {
            eventSink = nil
            sinkGeneration += 1
            return
        }
        eventSink = sink
        let generation = sinkGeneration
        let snapshot = cache
        DispatchQueue.main.async {
            guard eventSink != nil, generation == sinkGeneration else { return }
            snapshot.forEach { sink?($0) }
        }
    }

    static func emit(_ event: [String: Any]) {
        cache.append(event)
        while cache.count > maxCache {
            cache.removeFirst()
        }
        guard let sink = eventSink else { return }
        let generation = sinkGeneration
        DispatchQueue.main.async {
            guard eventSink != nil, generation == sinkGeneration else { return }
            sink(event)
        }
    }

    static func reset() {
        cache.removeAll()
    }
}
