import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../storage/secure_storage.dart';
import 'dio_client.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorage storage;
  final Logger logger;
  final AuthGuard guard;
  AuthInterceptor({
    required this.storage,
    required this.logger,
    required this.guard,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await storage.readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}

    logger.i('[REQ] ${options.method} ${options.uri}');
    if (options.data != null) {
      logger.d('Body: ${options.data}');
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    logger.i(
      '[RES] ${response.requestOptions.method} ${response.requestOptions.uri} → ${response.statusCode}',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final uri = err.requestOptions.uri.toString();
    logger.e(
      '[ERR] ${err.requestOptions.method} $uri → ${err.response?.statusCode}\n${err.message}',
    );

    final isLogin = uri.contains('/api/v1/auth/login');
    final status = err.response?.statusCode ?? 0;

    if (status == 401 && !isLogin) {
      // Clear token & trigger router guard
      await storage.clearAll();
      guard.setAuthed(false);
      // Router akan redirect karena refreshListenable berubah
    }
    super.onError(err, handler);
  }
}
