import Foundation

/// Normalizes BLE device names the same way flutter_blue_plus treats advName /
/// platformName: advertisement local names are distinct from platform/cached
/// names, and placeholder strings are not real names.
enum BleNameUtils {

    /// Name from the advertisement packet (CBAdvertisementDataLocalNameKey).
    static func normalizeAdvertisedName(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !isPlaceholder(trimmed) else {
            return nil
        }
        return trimmed
    }

    /// Platform/cached name (CBPeripheral.name).
    static func normalizePlatformName(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !isPlaceholder(trimmed) else {
            return nil
        }
        return trimmed
    }

    static func hasAdvertisedName(_ raw: String?) -> Bool {
        normalizeAdvertisedName(raw) != nil
    }

    private static func isPlaceholder(_ name: String) -> Bool {
        switch name.lowercased() {
        case "unknown", "(unknown)", "n/a", "null", "<unknown>":
            return true
        default:
            return false
        }
    }
}
