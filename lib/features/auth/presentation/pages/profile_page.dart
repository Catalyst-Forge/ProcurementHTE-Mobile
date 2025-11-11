import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_notifier.dart';
import '../controllers/auth_state.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authNotifierProvider);

    return switch (state) {
      AuthAuthenticated(user: final u) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: RefreshIndicator(
          onRefresh: () =>
              ref.read(authNotifierProvider.notifier).loadProfile(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.all(16),
            children: [
            // Avatar inisial (aman untuk fullName/userName/email yang nullable/non-nullable)
            Center(
              child: CircleAvatar(
                radius: 36,
                child: Text(
                  _avatarText(u.fullName, u.userName, u.email),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Display name dan email (null-safe)
            Center(
              child: Text(
                _displayName(u.fullName, u.userName, u.email),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                _orDash(u.email),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // Roles: tanpa ?? langsung di expression (hindari dead_null_aware_expression)
            ..._roleSection(u.roles),

            const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Berhasil logout')),
                    );
                  }
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),

      // Loading/placeholder aman (guard router yang mengarahkan ke login jika perlu)
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  // ---------- Helpers (null-safe & bebas warning) ----------

  String _displayName(String? fullName, String? userName, String? email) {
    final fn = fullName?.trim();
    if (fn != null && fn.isNotEmpty) return fn;

    final un = userName?.trim();
    if (un != null && un.isNotEmpty) return un;

    final em = email?.trim();
    if (em != null && em.isNotEmpty) return em;

    return '-';
  }

  String _avatarText(String? fullName, String? userName, String? email) {
    final name = _displayName(fullName, userName, email).trim();
    if (name.isEmpty || name == '-') return '?';
    // Hindari dependency characters; cukup ambil huruf pertama.
    return name.substring(0, 1).toUpperCase();
  }

  String _orDash(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? '-' : t;
  }

  /// Bangun section roles tanpa memakai `??` langsung di expression,
  /// agar tidak memicu dead_null_aware_expression ketika `roles` non-nullable.
  List<Widget> _roleSection(List<String>? rolesMaybe) {
    // Terima nullable/non-nullable dengan aman
    final List<String> roles = rolesMaybe ?? const <String>[];
    if (roles.isEmpty) return const <Widget>[];

    return <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: roles.map((r) => Chip(label: Text(r))).toList(),
      ),
    ];
  }
}
