// lib/features/weather/weather_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // kDebugMode, debugPrint
import 'weather_models.dart';

class WeatherService {
  WeatherService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;

  /// Ambil cuaca via nama kota (forward geocoding Open-Meteo → lanjut forecast)
  Future<WeatherBannerData> fetchByCity(String cityName) async {
    // 1) Geocoding (search)
    final geo = await _dio.get(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {
        'name': cityName,
        'count': 1,
        'language': 'id',
        'format': 'json',
      },
    );

    final results = (geo.data?['results'] as List?) ?? const [];
    if (results.isEmpty) {
      throw Exception('Kota tidak ditemukan: $cityName');
    }
    final first = results.first as Map<String, dynamic>;
    final double lat = (first['latitude'] as num).toDouble();
    final double lon = (first['longitude'] as num).toDouble();
    final String resolvedName = (first['name'] ?? cityName).toString();

    // 2) Forecast diambil di helper, sambil kirim fallbackName = resolvedName
    return _fetchForecast(lat: lat, lon: lon, fallbackName: resolvedName);
  }

  /// Ambil cuaca langsung dari koordinat
  Future<WeatherBannerData> fetchByLatLon({
    required double lat,
    required double lon,
    String? fallbackName,
  }) {
    return _fetchForecast(lat: lat, lon: lon, fallbackName: fallbackName);
  }

  // ----------------------------------------------------------------------------
  // Helper utama: ambil forecast + (opsional) reverse geocoding buat nama lokasi
  Future<WeatherBannerData> _fetchForecast({
    required double lat,
    required double lon,
    String? fallbackName,
  }) async {
    // Forecast (Open-Meteo)
    final fx = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'current_weather': true,
        'daily': 'temperature_2m_max,temperature_2m_min,weathercode',
        'timezone': 'auto',
      },
    );

    final current = fx.data?['current_weather'] as Map<String, dynamic>?;
    if (current == null) throw Exception('Data cuaca tidak tersedia');

    final int temp = (current['temperature'] as num?)?.round() ?? 0;
    final bool isDay = (current['is_day'] as num?) == 1;
    final int wcode = (current['weathercode'] as num?)?.toInt() ?? 0;

    int? h, l;
    final daily = fx.data?['daily'] as Map<String, dynamic>?;
    if (daily != null) {
      final List maxs = (daily['temperature_2m_max'] as List?) ?? const [];
      final List mins = (daily['temperature_2m_min'] as List?) ?? const [];
      if (maxs.isNotEmpty && mins.isNotEmpty) {
        h = (maxs.first as num).round();
        l = (mins.first as num).round();
      }
    }

    // Reverse geocoding (Nominatim OSM) → biar ada nama tempat yang enak
    String name = fallbackName ?? 'Lokasi Anda';
    try {
      name = await _reverseGeocodeNominatim(lat, lon, fallbackName: name);
    } catch (_) {
      // Abaikan jika gagal / rate limited → pakai fallbackName
    }

    // Bentuk data + log bukti
    final data = WeatherBannerData(
      location: name,
      temperatureC: temp,
      condition: _mapWeatherCodeToId(wcode),
      highC: h,
      lowC: l,
      isDaytime: isDay,
      lastUpdated: DateTime.now(),
    );

    if (kDebugMode) {
      debugPrint(
        '[WX] ${data.location} | ${data.temperatureC}° | ${data.condition} '
        '| H:${data.highC} L:${data.lowC} | isDay:${data.isDaytime}',
      );
    }

    return data;
  }

  // --- Reverse geocoding gratis via Nominatim (tanpa API key) ---
  Future<String> _reverseGeocodeNominatim(
    double lat,
    double lon, {
    String? fallbackName,
  }) async {
    final res = await _dio.get(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'lat': lat,
        'lon': lon,
        'format': 'jsonv2',
        'accept-language': 'id',
        'zoom': 10, // 10–12 ≈ level kota/kecamatan
      },
      options: Options(
        // Wajib: Nominatim minta User-Agent yang jelas
        headers: {'User-Agent': 'approvals-hte/1.0 (support@catalystforge.id)'},
      ),
    );

    final data = res.data as Map<String, dynamic>?;
    final addr = data?['address'] as Map<String, dynamic>?;

    final city =
        addr?['city'] ??
        addr?['town'] ??
        addr?['village'] ??
        addr?['municipality'] ??
        addr?['county'];

    final name =
        (city ??
                data?['name'] ??
                data?['display_name'] ??
                fallbackName ??
                'Lokasi Anda')
            .toString();

    return name;
  }

  // Mapping WMO → label Indonesia
  String _mapWeatherCodeToId(int code) {
    switch (code) {
      case 0:
        return 'Cerah';
      case 1:
        return 'Cerah Berawan';
      case 2:
        return 'Berawan Sebagian';
      case 3:
        return 'Berawan';
      case 45:
      case 48:
        return 'Berkabut';
      case 51:
      case 53:
      case 55:
        return 'Gerimis';
      case 56:
      case 57:
        return 'Gerimis Beku';
      case 61:
      case 63:
      case 65:
        return 'Hujan';
      case 66:
      case 67:
        return 'Hujan Beku';
      case 71:
      case 73:
      case 75:
        return 'Salju';
      case 77:
        return 'Butiran Salju';
      case 80:
      case 81:
      case 82:
        return 'Hujan Lokal';
      case 85:
      case 86:
        return 'Salju Lokal';
      case 95:
        return 'Guntur/Badai';
      case 96:
      case 99:
        return 'Badai Petir Disertai Hujan';
      default:
        return 'Kondisi Tidak Diketahui';
    }
  }
}
