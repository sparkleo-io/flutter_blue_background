package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.util.Log

/**
 * Centralized, level-filtered logging for flutter_blue_background on Android.
 *
 * All messages are tagged [TAG] and prefixed with a styled level label so they
 * are easy to filter in logcat (`adb logcat -s FBB`).
 */
enum class FbbLogLevel {
    NONE,
    ERROR,
    WARNING,
    INFO,
    DEBUG,
    VERBOSE,
}

object FbbLog {
    private const val TAG = "FBB"

    @Volatile
    var level: FbbLogLevel = FbbLogLevel.DEBUG
        private set

    @Volatile
    private var bannerShown = false

    fun setLevel(ordinal: Int) {
        level = FbbLogLevel.entries.getOrElse(ordinal) { FbbLogLevel.DEBUG }
        if (level != FbbLogLevel.NONE) {
            printBanner()
        }
    }

    fun error(message: String) = log(FbbLogLevel.ERROR, message)

    fun warning(message: String) = log(FbbLogLevel.WARNING, message)

    fun info(message: String) = log(FbbLogLevel.INFO, message)

    fun debug(message: String) = log(FbbLogLevel.DEBUG, message)

    fun verbose(message: String) = log(FbbLogLevel.VERBOSE, message)

    private fun printBanner() {
        if (bannerShown) return
        bannerShown = true
        Log.i(
            TAG,
            """
            |══════
            |  FBB
            |══════
            """.trimMargin(),
        )
    }

    private fun log(level: FbbLogLevel, message: String) {
        if (this.level == FbbLogLevel.NONE) return
        if (level.ordinal > this.level.ordinal) return
        printBanner()
        val prefix = when (level) {
            FbbLogLevel.ERROR -> "✖ ERROR  │"
            FbbLogLevel.WARNING -> "⚠ WARN   │"
            FbbLogLevel.INFO -> "ℹ INFO   │"
            FbbLogLevel.DEBUG -> "● DEBUG  │"
            FbbLogLevel.VERBOSE -> "› VERBOSE│"
            FbbLogLevel.NONE -> return
        }
        val line = "$prefix $message"
        when (level) {
            FbbLogLevel.ERROR -> Log.e(TAG, line)
            FbbLogLevel.WARNING -> Log.w(TAG, line)
            FbbLogLevel.INFO -> Log.i(TAG, line)
            else -> Log.d(TAG, line)
        }
    }
}
