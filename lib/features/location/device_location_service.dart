import 'package:geolocator/geolocator.dart';

class LocationDeniedForever implements Exception {}

class LocationServiceDisabled implements Exception {}

class DeviceLocationService {
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceDisabled();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw PermissionDeniedException('Izin lokasi ditolak.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationDeniedForever();
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low, // cukup untuk cuaca
    );
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
