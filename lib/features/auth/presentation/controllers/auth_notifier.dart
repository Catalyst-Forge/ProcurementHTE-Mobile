import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:approvals_hte/core/network/dio_client.dart' as net hide secureStorageProvider;
import 'package:approvals_hte/core/storage/secure_storage.dart' as store;
import '../../data/auth_repository.dart';
import '../../domain/models/login_request.dart';
import 'auth_state.dart';

// Provider pakai NotifierProvider (Riverpod v3)
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repo;
  late final store.SecureStorage _storage;
  late final net.AuthGuard _guard;

  @override
  AuthState build() {
    _repo = ref.read(authRepositoryProvider);
    _storage = ref.read(store.secureStorageProvider);
    _guard = ref.read(net.authGuardProvider);
    return const AuthUnauthenticated();
  }

  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    try {
      final resp = await _repo.login(
        LoginRequest(email: email, password: password),
      );
      final user = resp.user;
      if (user == null) {
        state = const AuthError('Login berhasil tapi profil kosong.');
        _guard.setAuthed(false);
        return;
      }
      state = AuthAuthenticated(user);
      _guard.setAuthed(true);
    } catch (e) {
      state = AuthError(e.toString());
      _guard.setAuthed(false);
    }
  }

  Future<void> loadProfile() async {
    try {
      final token = await _storage.readToken();
      if (token == null || token.isEmpty) {
        state = const AuthUnauthenticated();
        _guard.setAuthed(false);
        return;
      }
      state = const AuthLoading();
      final user = await _repo.getProfile();
      state = AuthAuthenticated(user);
      _guard.setAuthed(true);
    } catch (_) {
      state = const AuthUnauthenticated();
      _guard.setAuthed(false);
    }
  }

  Future<void> logout() async {
    state = const AuthLoading();
    await _repo.logout();
    state = const AuthUnauthenticated();
    _guard.setAuthed(false);
  }
}
