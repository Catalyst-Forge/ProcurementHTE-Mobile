// lib/core/error/http_error_mapper.dart
import 'package:dio/dio.dart';
import 'failures.dart';

AppFailure mapDioError(Object e) {
  if (e is DioException) {
    final status = e.response?.statusCode;
    final msg = e.message ?? 'Terjadi kesalahan jaringan';
    if (status == 401) {
      return UnauthorizedFailure(
        'Sesi berakhir. Silakan login lagi.',
        code: status,
      );
    }
    if (status != null && status >= 500) {
      return ServerFailure('Server bermasalah ($status)', code: status);
    }
    return NetworkFailure(msg, code: status);
  }
  return ServerFailure(e.toString());
}
