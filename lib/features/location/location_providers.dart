import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'device_location_service.dart';

final deviceLocationServiceProvider = Provider<DeviceLocationService>((ref) {
  return DeviceLocationService();
});

final devicePositionProvider = FutureProvider.autoDispose<Position>((
  ref,
) async {
  final keep = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 10), keep.close);
  ref.onDispose(() {
    timer.cancel();
    keep.close();
  });

  final svc = ref.watch(deviceLocationServiceProvider);
  return svc.getCurrentPosition();
});
