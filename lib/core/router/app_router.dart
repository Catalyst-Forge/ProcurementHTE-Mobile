// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:approvals_hte/features/scan/presentation/pages/scan_page.dart';
import 'package:approvals_hte/features/scan/presentation/pages/auto_action_page.dart';
import 'package:approvals_hte/features/scan/presentation/pages/auto_single_action_page.dart';
import 'package:approvals_hte/features/scan/presentation/pages/document_grid_page.dart';
import 'package:approvals_hte/features/auth/presentation/pages/login_page.dart';
import 'package:approvals_hte/features/splash/presentation/splash_page.dart';
import 'tab_navigator.dart';
// Pakai alias agar tidak bentrok provider SecureStorage di dio_client.dart
import 'package:approvals_hte/core/network/dio_client.dart' as net;
import 'package:approvals_hte/core/storage/secure_storage.dart' as store;

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}

final routerProvider = Provider<GoRouter>((ref) {
  final guard = ref.watch(net.authGuardProvider);

  return GoRouter(
    navigatorKey: AppRouter.navigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: guard,
    redirect: (context, state) {
      final authed = guard.isAuthed;
      final loc = state.matchedLocation;

      // Biarkan splash jalan
      if (loc == '/splash') return null;

      // Hanya /main yang butuh login
      final needsAuth = loc.startsWith('/main') ||
          loc.startsWith('/scan') ||
          loc.startsWith('/documents') ||
          loc.startsWith('/auto-approve') ||
          loc.startsWith('/auto-reject') ||
          loc.startsWith('/auto-approve-single') ||
          loc.startsWith('/auto-reject-single');
      if (!authed && needsAuth) return '/login';
      if (authed && (loc == '/login' || loc == '/')) return '/main';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/splash'),
      GoRoute(path: '/splash', builder: (ctx, st) => const SplashPage()),
      GoRoute(path: '/login', builder: (ctx, st) => const LoginPage()),
      // ⬇️ Shell sederhana (TIDAK pakai StatefulShellRoute)
      GoRoute(
        path: '/main',
        pageBuilder: (ctx, st) => const NoTransitionPage(
          key: ValueKey('main-shell-page'),
          child: _MainShell(key: ValueKey('main-shell')),
        ),
      ),
      GoRoute(path: '/scan', builder: (ctx, st) => const ScanPage()),
      GoRoute(
        path: '/documents',
        builder: (ctx, st) {
          final qr = st.uri.queryParameters['qr'];
          return DocumentGridPage(
            initialQrText:
                (qr != null && qr.isNotEmpty) ? Uri.decodeComponent(qr) : null,
          );
        },
      ),
      GoRoute(
        path: '/auto-approve',
        builder: (ctx, st) => const AutoApprovePage(),
      ),
      GoRoute(
        path: '/auto-reject',
        builder: (ctx, st) => const AutoRejectPage(),
      ),
      GoRoute(
        path: '/auto-approve-single',
        builder: (ctx, st) => const AutoApproveSinglePage(),
      ),
      GoRoute(
        path: '/auto-reject-single',
        builder: (ctx, st) => const AutoRejectSinglePage(),
      ),
    ],
  );
});

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell({super.key});
  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final PageController _page;
  TabController? _tab; // nullable → aman dari late init
  bool _booted = false; // placeholder sampai siap render bar

  // Navigator per tab (stack independen)
  final _homeKey = GlobalKey<NavigatorState>();
  final _filesKey = GlobalKey<NavigatorState>();
  final _profileKey = GlobalKey<NavigatorState>();
  List<GlobalKey<NavigatorState>> get _tabKeys => [
    _homeKey,
    _filesKey,
    _profileKey,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _page = PageController(initialPage: _currentIndex);
    _tab = TabController(length: 3, vsync: this, initialIndex: _currentIndex);
    _booted = true;

    _restoreLastTab();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tab?.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (_page.hasClients) _page.jumpToPage(_currentIndex);
      final t = _tab;
      if (t != null && t.index != _currentIndex) t.index = _currentIndex;
      setState(() {}); // redraw Convex
    }
  }

  Future<void> _restoreLastTab() async {
    final s = ref.read(store.secureStorageProvider);
    final idx = await s.readLastTab();
    if (!mounted) return;
    if (idx == null || idx < 0 || idx > 2) return;
    setState(() => _currentIndex = idx);
    _page.jumpToPage(idx);
    _tab?.index = idx;
  }

  Future<void> _persist() async {
    final s = ref.read(store.secureStorageProvider);
    await s.saveLastTab(_currentIndex);
  }

  void _onTabTap(int i) {
    if (i == _currentIndex) {
      // Tap tab aktif → pop to root pada stack tab itu
      final nav = _tabKeys[i].currentState!;
      while (nav.canPop()) {
        nav.pop();
      }
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = i);
    _page.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _persist();
  }

  void _onPageChanged(int i) {
    if (i == _currentIndex) return;
    setState(() => _currentIndex = i);
    final t = _tab;
    if (t != null && t.index != i) t.index = i;
    _persist();
  }

  bool _handleBackPressed() {
    final nav = _tabKeys[_currentIndex].currentState!;
    if (nav.canPop()) {
      nav.pop();
      return true;
    }
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      _page.animateToPage(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      final t = _tab;
      if (t != null && t.index != 0) t.index = 0;
      return true;
    }
    SystemNavigator.pop(); // keluar ke menu Android
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const double barHeight = 62;

    // Tampilkan FAB hanya:
    // - di tab Home (index 0)
    // - dan lagi di root Home (tidak sedang di halaman detail)
    final bool showScanFab =
        _currentIndex == 0 && !(_homeKey.currentState?.canPop() ?? false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPressed();
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            PageView(
              controller: _page,
              physics: const ClampingScrollPhysics(),
              onPageChanged: _onPageChanged,
              children: [
                HomeTabNavigator(navigatorKey: _homeKey),
                FilesTabNavigator(navigatorKey: _filesKey),
                ProfileTabNavigator(navigatorKey: _profileKey),
              ],
            ),

            // FAB hanya muncul di Home root
            if (showScanFab)
              Positioned(
                right: 16,
                bottom: barHeight + bottomPad + 16,
                child: FloatingActionButton.extended(
                  heroTag: 'fab-scan',
                  onPressed: () {
                    // langsung push ke halaman scan
                    context.push('/scan');
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan'),
                ),
              ),
          ],
        ),

        bottomNavigationBar: !_booted || _tab == null
            ? SizedBox(height: barHeight + bottomPad)
            : SizedBox(
                height: barHeight + bottomPad,
                child: Material(
                  color: Colors.transparent,
                  child: ConvexAppBar(
                    controller: _tab!,
                    style: TabStyle.reactCircle,
                    height: barHeight,
                    elevation: 10,
                    backgroundColor: cs.surface,
                    color: cs.onSurface.withValues(alpha: 0.7),
                    activeColor: cs.primary,
                    items: const [
                      TabItem(icon: Icons.home_rounded, title: 'Home'),
                      TabItem(icon: Icons.monitor, title: 'Monitoring'),
                      TabItem(icon: Icons.person_rounded, title: 'Profile'),
                    ],
                    onTap: _onTabTap,
                  ),
                ),
              ),
      ),
    );
  }
}
