/// Structured plugin error with an `FBB:` prefix on [message].
class FbbException implements Exception {
  FbbException(this.method, this.message, {this.errorCode});

  final String method;
  final String message;
  final int? errorCode;

  @override
  String toString() => 'FbbException($method): $message';
}
