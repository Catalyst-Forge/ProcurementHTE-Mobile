class WeatherBannerData {
  final String location;
  final int temperatureC;
  final String condition; // “Cerah”, “Berawan”, dll
  final int? highC; // Max hari ini
  final int? lowC; // Min hari ini
  final bool isDaytime; // Siang/malam
  final DateTime lastUpdated;

  const WeatherBannerData({
    required this.location,
    required this.temperatureC,
    required this.condition,
    required this.isDaytime,
    required this.lastUpdated,
    this.highC,
    this.lowC,
  });
}
