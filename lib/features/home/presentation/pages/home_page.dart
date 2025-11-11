import 'package:approvals_hte/core/widgets/weather_banner_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/weather_banner.dart';
import '../../../../core/widgets/weather_banner_skeleton.dart';
import '../../../../features/weather/weather_providers.dart';
import '../../../../features/location/location_providers.dart';
import '../widgets/menu_grid.dart';
import '../widgets/menu_grid_skeleton.dart';

final homeMenuRefreshingProvider =
    NotifierProvider<_HomeMenuRefreshNotifier, bool>(
  _HomeMenuRefreshNotifier.new,
);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const String defaultCity = 'Bandung';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(homeWeatherProvider(defaultCity));
    final posAsync = ref.watch(devicePositionProvider);
    final isMenuRefreshing = ref.watch(homeMenuRefreshingProvider);
    final showMenuSkeleton = weatherAsync.isLoading &&
        (!weatherAsync.hasValue || isMenuRefreshing);

    void invalidateWeather() {
      ref.invalidate(devicePositionProvider);
      ref.invalidate(weatherByPositionProvider);
      ref.invalidate(homeWeatherProvider(defaultCity));
    }

    Future<void> handleRefresh() async {
      ref.read(homeMenuRefreshingProvider.notifier).setRefreshing(true);
      invalidateWeather();
      try {
        final refreshed =
            ref.refresh(homeWeatherProvider(defaultCity).future);
        await refreshed;
      } finally {
        ref.read(homeMenuRefreshingProvider.notifier).setRefreshing(false);
      }
    }

    final sourceLabel = posAsync.when(
      data: (_) => 'Sumber: GPS (lokasi perangkat)',
      loading: () => 'Sumber: Meminta izin lokasi…',
      error: (_, __) => 'Sumber: Fallback kota ($defaultCity)',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Procurement Approvals'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              weatherAsync.when(
                data: (w) => WeatherBanner(
                  location: w.location,
                  temperatureC: w.temperatureC,
                  condition: w.condition,
                  highC: w.highC,
                  lowC: w.lowC,
                  isDaytime: w.isDaytime,
                  lastUpdated: w.lastUpdated,
                  onTap: invalidateWeather,
                ),
                loading: () => const WeatherBannerSkeleton(),
                error: (e, _) => WeatherBannerError(
                  e.toString(),
                  onRetry: invalidateWeather,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sourceLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: showMenuSkeleton
                    ? const MenuGridSkeleton(key: ValueKey('menu-skel'))
                    : const MenuGrid(key: ValueKey('menu-grid')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMenuRefreshNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setRefreshing(bool value) => state = value;
}
