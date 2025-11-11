import 'package:flutter/material.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/home_detail_page.dart';
import '../../features/home/presentation/pages/empty_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';

/// Wrapper KeepAlive biar state di tiap tab nggak ke-reset saat pindah tab.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

/// Navigator khusus tab Home
class HomeTabNavigator extends StatelessWidget {
  const HomeTabNavigator({super.key, required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return _KeepAlive(
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(
                builder: (_) => const HomePage(),
                settings: settings,
              );
            case '/detail':
              final id = (settings.arguments as String?) ?? '-';
              return MaterialPageRoute(
                builder: (_) => HomeDetailPage(itemId: id),
                settings: settings,
              );
            default:
              return MaterialPageRoute(
                builder: (_) => const HomePage(),
                settings: settings,
              );
          }
        },
      ),
    );
  }
}

/// Navigator khusus tab Files
class FilesTabNavigator extends StatelessWidget {
  const FilesTabNavigator({super.key, required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return _KeepAlive(
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(
                builder: (_) => const EmptyPage(title: 'Monitoring'),
                settings: settings,
              );
            // Tambah route lain untuk files kalau perlu
            default:
              return MaterialPageRoute(
                builder: (_) => const EmptyPage(title: 'Monitoring'),
                settings: settings,
              );
          }
        },
      ),
    );
  }
}

/// Navigator khusus tab Profile
class ProfileTabNavigator extends StatelessWidget {
  const ProfileTabNavigator({super.key, required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return _KeepAlive(
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(
                builder: (_) => const ProfilePage(),
                settings: settings,
              );
            default:
              return MaterialPageRoute(
                builder: (_) => const ProfilePage(),
                settings: settings,
              );
          }
        },
      ),
    );
  }
}
