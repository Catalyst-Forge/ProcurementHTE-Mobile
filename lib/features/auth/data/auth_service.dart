import 'package:dio/dio.dart';
import '../../auth/domain/models/login_request.dart';
import '../../auth/domain/models/login_response.dart';
import '../../auth/domain/models/user.dart';

class AuthService {
  final Dio _dio;
  AuthService(this._dio);

  Future<LoginResponse> login(LoginRequest body) async {
    final res = await _dio.post('/api/v1/auth/login', data: body.toMap());
    return LoginResponse.fromMap(res.data as Map<String, dynamic>);
  }

  Future<User> getProfile() async {
    final res = await _dio.get('/api/v1/auth/profile');
    return User.fromMap(res.data as Map<String, dynamic>);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post(
      '/api/v1/auth/logout',
      data: {'refreshToken': refreshToken},
    );
  }
}
