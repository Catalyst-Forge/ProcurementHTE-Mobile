import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // penting utk ChangeNotifier/Listenable
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../logging/app_logger.dart';
import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';

class AppFailure implements Exception {
  final String message;
  final int? code;
  AppFailure(this.message, {this.code});
  @override
  String toString() => 'AppFailure(code: $code, message: $message)';
}

final loggerProvider = Provider((ref) => AppLogger.logger);
final secureStorageProvider = Provider((ref) => SecureStorage());

class AuthGuard extends ChangeNotifier {
  bool _isAuthed = false;
  bool get isAuthed => _isAuthed;
  void setAuthed(bool val) {
    if (_isAuthed == val) return;
    _isAuthed = val;
    notifyListeners(); // sekarang ada
  }
}

final authGuardProvider = Provider((ref) => AuthGuard());

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  final logger = ref.read(loggerProvider);
  final guard = ref.read(authGuardProvider);

  final options = BaseOptions(
    baseUrl: Env.baseUrl,
    connectTimeout: Env.connectTimeout,
    receiveTimeout: Env.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  );

  final dio = Dio(options);
  dio.interceptors.add(
    AuthInterceptor(storage: storage, logger: logger, guard: guard),
  );
  return dio;
});

AppFailure mapDioError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return AppFailure('Gagal terhubung ke server (timeout).');
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode;
      final data = e.response?.data;
      final String msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'Kesalahan server ($code).';
      return AppFailure(msg, code: code);
    case DioExceptionType.connectionError:
      return AppFailure('Tidak ada koneksi internet.');
    case DioExceptionType.cancel:
      return AppFailure('Permintaan dibatalkan.');
    case DioExceptionType.badCertificate:
      return AppFailure('Sertifikat TLS tidak valid.');
    case DioExceptionType.unknown:
      return AppFailure('Terjadi kesalahan jaringan.');
  }
}
