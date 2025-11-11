import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../location/location_providers.dart';
import 'weather_models.dart';
import 'weather_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: true, // tampilkan body -> bukti data masuk
      ),
    );
  }
  return dio;
});

final weatherServiceProvider = Provider<WeatherService>((ref) {
  final dio = ref.watch(dioProvider);
  return WeatherService(dio: dio);
});

final weatherByCityProvider = FutureProvider.family
    .autoDispose<WeatherBannerData, String>((ref, city) {
      final keep = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 10), keep.close);
      ref.onDispose(() {
        timer.cancel();
        keep.close();
      });

      final svc = ref.watch(weatherServiceProvider);
      return svc.fetchByCity(city);
    });

final weatherByPositionProvider = FutureProvider.autoDispose<WeatherBannerData>(
  (ref) async {
    final keep = ref.keepAlive();
    final timer = Timer(const Duration(minutes: 10), keep.close);
    ref.onDispose(() {
      timer.cancel();
      keep.close();
    });

    final svc = ref.watch(weatherServiceProvider);
    final pos = await ref.watch(devicePositionProvider.future);
    return svc.fetchByLatLon(lat: pos.latitude, lon: pos.longitude);
  },
);

/// Provider agregator: coba lokasi device, kalau gagal fallback ke kota default
final homeWeatherProvider = FutureProvider.family
    .autoDispose<WeatherBannerData, String>((ref, fallbackCity) async {
      try {
        return await ref.watch(weatherByPositionProvider.future);
      } catch (_) {
        return ref.watch(weatherByCityProvider(fallbackCity).future);
      }
    });
