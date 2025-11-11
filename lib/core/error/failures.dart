// lib/core/error/failures.dart
sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});
  final String message;
  final int? code;
  @override
  String toString() => 'AppFailure($code): $message';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.code});
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure(super.message, {super.code});
}

final class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {super.code});
}

final class ParseFailure extends AppFailure {
  const ParseFailure(super.message, {super.code});
}
