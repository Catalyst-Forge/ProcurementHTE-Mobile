// lib/core/storage/secure_storage.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _tokenKey = 'auth_token';
  static const _refreshKey = 'refresh_token';
  static const _lastTabKey = 'last_tab';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async =>
      _storage.write(key: _tokenKey, value: token);
  Future<String?> readToken() async => _storage.read(key: _tokenKey);
  Future<void> deleteToken() async => _storage.delete(key: _tokenKey);

  Future<void> saveRefresh(String refresh) async =>
      _storage.write(key: _refreshKey, value: refresh);
  Future<String?> readRefresh() async => _storage.read(key: _refreshKey);
  Future<void> deleteRefresh() async => _storage.delete(key: _refreshKey);

  Future<void> saveLastTab(int index) async =>
      _storage.write(key: _lastTabKey, value: index.toString());
  Future<int?> readLastTab() async {
    final v = await _storage.read(key: _lastTabKey);
    if (v == null) return null;
    final i = int.tryParse(v);
    return i;
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _lastTabKey);
  }
}

final secureStorageProvider = Provider<SecureStorage>((_) => SecureStorage());
