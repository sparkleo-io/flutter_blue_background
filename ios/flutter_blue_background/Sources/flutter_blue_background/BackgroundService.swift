import Foundation
import UIKit
import AVFoundation

/// BackgroundService - keeps the app alive in the background.
///
/// iOS has no concept of an Android-style foreground service. Instead this
/// uses `UIApplication` background tasks to extend background execution, and
/// (optionally) a silent audio loop. Long-lived BLE background execution comes
/// from the `bluetooth-central` UIBackgroundMode declared in the host app's
/// Info.plist; this service complements that by holding a background task while
/// transitioning in and out of the background.
class BackgroundService: NSObject {

    static let shared = BackgroundService()

    private var isRunning = false
    private var audioPlayer: AVAudioPlayer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private override init() {
        super.init()
    }

    /// Start the background service.
    func start() {
        guard !isRunning else {
            FbbLog.info("BackgroundService already running")
            return
        }

        isRunning = true
        FbbLog.info("Starting BackgroundService")

        setupBackgroundTaskHandling()

        // Optional: uncomment to enable silent audio keep-alive (see warning below).
        // setupSilentAudio()

        FbbLog.info("BackgroundService started")
    }

    /// Stop the background service.
    func stop() {
        guard isRunning else { return }

        isRunning = false
        FbbLog.info("Stopping BackgroundService")

        NotificationCenter.default.removeObserver(self)
        stopSilentAudio()
        endBackgroundTask()

        FbbLog.info("BackgroundService stopped")
    }

    // MARK: - Background Task Handling

    private func setupBackgroundTaskHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        FbbLog.info("Entered background")
        startBackgroundTask()
    }

    @objc private func appWillEnterForeground() {
        FbbLog.info("Entering foreground")
        endBackgroundTask()
    }

    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task first.

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            guard let self = self else { return }
            FbbLog.info("Background task expiring")
            self.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    // MARK: - Silent Audio (Optional - use with caution)

    /// Setup silent audio to keep the app alive.
    ///
    /// WARNING: this approach is controversial and may be rejected by App Store
    /// review. Only use it if you have a valid, documented use case. It requires
    /// the `audio` UIBackgroundMode and a bundled `silence.mp3` resource.
    private func setupSilentAudio() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)

            guard let soundURL = Bundle.main.url(forResource: "silence", withExtension: "mp3") else {
                FbbLog.error("Silent audio file not found")
                return
            }

            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1 // Infinite loop
            audioPlayer?.volume = 0.01 // Very low volume
            audioPlayer?.play()

            FbbLog.info("Silent audio started")
        } catch {
            FbbLog.error("Failed to setup silent audio: \(error.localizedDescription)")
        }
    }

    private func stopSilentAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Status

    func isServiceRunning() -> Bool {
        return isRunning
    }

    func getServiceStatus() -> [String: Any] {
        return [
            "isRunning": isRunning,
            "backgroundTimeRemaining": UIApplication.shared.backgroundTimeRemaining
        ]
    }
}
