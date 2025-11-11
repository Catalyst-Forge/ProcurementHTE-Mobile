import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:approvals_hte/core/network/dio_client.dart' as net hide secureStorageProvider;
import 'package:approvals_hte/core/storage/secure_storage.dart' as store;
import '../domain/models/login_request.dart';
import '../domain/models/login_response.dart';
import '../domain/models/user.dart';
import 'auth_service.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.read(net.dioProvider)),
);
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.read(authServiceProvider),
    ref.read(store.secureStorageProvider),
  ),
);

class AuthRepository {
  final AuthService _service;
  final store.SecureStorage _storage;
  AuthRepository(this._service, this._storage);

  Future<LoginResponse> login(LoginRequest req) async {
    try {
      final resp = await _service.login(req);
      await _storage.saveToken(resp.token);

      final rt = resp.refreshToken; // ideally String?
      if (rt != null && rt.isNotEmpty) {
        await _storage.saveRefresh(rt);
      }
      return resp;
    } on DioException catch (e) {
      throw net.mapDioError(e);
    }
  }

  Future<User> getProfile() async {
    try {
      return await _service.getProfile();
    } on DioException catch (e) {
      throw net.mapDioError(e);
    }
  }

  Future<void> logout() async {
    try {
      final refresh = await _storage.readRefresh();
      if (refresh != null && refresh.isNotEmpty) {
        await _service.logout(refresh);
      }
    } on DioException catch (_) {
      // abaikan
    } finally {
      await _storage.clearAll();
    }
  }
}
