class AppException implements Exception {
  final String message;
  final String? code;
  const AppException(this.message, {this.code});
  @override
  String toString() => message;
}

class OfflineException extends AppException {
  const OfflineException() : super('You are offline. Check your connection.');
}
