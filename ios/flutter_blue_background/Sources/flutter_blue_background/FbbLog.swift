import Foundation
import os.log

enum FbbLogLevel: Int, CaseIterable {
  case none = 0
  case error = 1
  case warning = 2
  case info = 3
  case debug = 4
  case verbose = 5
}

enum FbbLog {
  private static let subsystem = "com.sparkleo.flutter_blue_background"
  private static let log = OSLog(subsystem: subsystem, category: "FBB")

  private static var level: FbbLogLevel = .debug
  private static var bannerShown = false

  static func setLevel(_ ordinal: Int) {
    level = FbbLogLevel(rawValue: ordinal) ?? .debug
    if level != .none {
      printBanner()
    }
  }

  static func error(_ message: String) { log(.error, message) }
  static func warning(_ message: String) { log(.warning, message) }
  static func info(_ message: String) { log(.info, message) }
  static func debug(_ message: String) { log(.debug, message) }
  static func verbose(_ message: String) { log(.verbose, message) }

  private static func printBanner() {
    guard !bannerShown else { return }
    bannerShown = true
    let banner = """
    ══════
      FBB
    ══════
    """
    os_log("%{public}@", log: log, type: .info, banner)
  }

  private static func log(_ messageLevel: FbbLogLevel, _ message: String) {
    guard level != .none else { return }
    guard messageLevel.rawValue <= level.rawValue else { return }
    printBanner()
    let prefix: String
    switch messageLevel {
    case .error: prefix = "✖ ERROR  │"
    case .warning: prefix = "⚠ WARN   │"
    case .info: prefix = "ℹ INFO   │"
    case .debug: prefix = "● DEBUG  │"
    case .verbose: prefix = "› VERBOSE│"
    case .none: return
    }
    let line = "\(prefix) \(message)"
    let osType: OSLogType = switch messageLevel {
    case .error: .error
    case .warning: .fault
    case .info: .info
    default: .debug
    }
    os_log("%{public}@", log: log, type: osType, line)
  }
}
