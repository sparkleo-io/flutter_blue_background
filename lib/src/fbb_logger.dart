import 'dart:async';

import 'fbb_log_level.dart';

/// Internal logger for flutter_blue_background.
///
/// Produces styled console output with an `FBB` banner and ANSI colors when
/// [color] is enabled (default). A plain-text copy is also pushed to [logs].
class FbbLogger {
  FbbLogger._();

  static FbbLogLevel _level = FbbLogLevel.debug;
  static bool _color = true;
  static bool _bannerShown = false;

  static final StreamController<String> _logsController =
      StreamController<String>.broadcast();

  static FbbLogLevel get level => _level;

  static bool get color => _color;

  /// Plain-text log stream (ANSI stripped). Useful for in-app debug consoles.
  static Stream<String> get logs => _logsController.stream;

  static void configure(FbbLogLevel level, {bool color = true}) {
    _level = level;
    _color = color;
    if (level != FbbLogLevel.none) {
      _printBanner();
    }
  }

  static void error(String message, {String? tag}) =>
      _log(FbbLogLevel.error, message, tag: tag);

  static void warning(String message, {String? tag}) =>
      _log(FbbLogLevel.warning, message, tag: tag);

  static void info(String message, {String? tag}) =>
      _log(FbbLogLevel.info, message, tag: tag);

  static void debug(String message, {String? tag}) =>
      _log(FbbLogLevel.debug, message, tag: tag);

  static void verbose(String message, {String? tag}) =>
      _log(FbbLogLevel.verbose, message, tag: tag);

  /// Logs an outgoing method-channel call (verbose only).
  static void logMethodArgs(String method, Object? args) {
    if (_level != FbbLogLevel.verbose) return;
    final methodPart = _styled('<$method>', _Ansi.boldBlack);
    final argsPart = _styled('args: $args', _Ansi.boldMagenta);
    _emit(FbbLogLevel.verbose, '$methodPart $argsPart', tag: 'Dart');
  }

  /// Logs a method-channel result (verbose only).
  static void logMethodResult(String method, Object? result) {
    if (_level != FbbLogLevel.verbose) return;
    final methodPart = _styled('($method)', _Ansi.boldBlack);
    final resultPart = _styled('result: $result', _Ansi.boldYellow);
    _emit(FbbLogLevel.verbose, '$methodPart $resultPart', tag: 'Dart');
  }

  static void _log(FbbLogLevel level, String message, {String? tag}) {
    if (_level == FbbLogLevel.none) return;
    if (level.index > _level.index) return;
    _emit(level, message, tag: tag);
  }

  static void _emit(FbbLogLevel level, String message, {String? tag}) {
    _printBanner();
    final prefix = _levelPrefix(level);
    final tagPart = tag != null ? '${_styled('[$tag]', _Ansi.dim)} ' : '';
    final line = '$prefix $tagPart$message';
    final plain = _stripAnsi('$prefix $tagPart$message');
    _logsController.add(plain);
    // ignore: avoid_print
    print(line);
  }

  static void _printBanner() {
    if (_bannerShown) return;
    _bannerShown = true;
    const plain = '══════\n  FBB\n══════';
    final styled =
        _color ? '${_Ansi.boldCyan}══════\n  FBB\n══════${_Ansi.reset}' : plain;
    _logsController.add(plain);
    // ignore: avoid_print
    print(styled);
  }

  static String _levelPrefix(FbbLogLevel level) {
    return switch (level) {
      FbbLogLevel.error => _styled('✖ ERROR  ', _Ansi.boldRed),
      FbbLogLevel.warning => _styled('⚠ WARN   ', _Ansi.boldYellow),
      FbbLogLevel.info => _styled('ℹ INFO   ', _Ansi.boldCyan),
      FbbLogLevel.debug => _styled('● DEBUG  ', _Ansi.boldGreen),
      FbbLogLevel.verbose => _styled('› VERBOSE', _Ansi.boldMagenta),
      FbbLogLevel.none => '',
    };
  }

  static String _styled(String text, String ansi) {
    if (!_color) return text;
    return '$ansi$text${_Ansi.reset}';
  }

  static String _stripAnsi(String value) {
    final result = StringBuffer();
    var i = 0;
    while (i < value.length) {
      if (value.codeUnitAt(i) == 0x1B &&
          i + 1 < value.length &&
          value.codeUnitAt(i + 1) == 0x5B) {
        i += 2;
        while (i < value.length && value.codeUnitAt(i) != 0x6D) {
          i++;
        }
        if (i < value.length) i++;
      } else {
        result.writeCharCode(value.codeUnitAt(i));
        i++;
      }
    }
    return result.toString();
  }
}

class _Ansi {
  static const reset = '\x1B[0m';
  static const dim = '\x1B[2m';
  static const boldBlack = '\x1B[1;30m';
  static const boldRed = '\x1B[1;31m';
  static const boldYellow = '\x1B[1;33m';
  static const boldGreen = '\x1B[1;32m';
  static const boldCyan = '\x1B[1;36m';
  static const boldMagenta = '\x1B[1;35m';
}
