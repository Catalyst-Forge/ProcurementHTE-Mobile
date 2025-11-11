// lib/core/widgets/weather_banner.dart
import 'package:flutter/material.dart';

class WeatherBanner extends StatelessWidget {
  const WeatherBanner({
    super.key,
    required this.location,
    required this.temperatureC,
    required this.condition,
    this.highC,
    this.lowC,
    this.lastUpdated,
    this.onTap,
    this.isDaytime = true,
  });

  final String location;
  final int temperatureC;
  final String condition;
  final int? highC;
  final int? lowC;
  final DateTime? lastUpdated;
  final VoidCallback? onTap;
  final bool isDaytime;

  IconData get _icon {
    final c = condition.toLowerCase();
    // Tambah curly braces {} agar lolos lint
    if (c.contains('hujan')) {
      return Icons.beach_access;
    }
    if (c.contains('badai') || c.contains('guntur')) {
      return Icons.thunderstorm_outlined;
    }
    if (c.contains('kabut')) {
      return Icons.blur_on;
    }
    if (c.contains('awan')) {
      return Icons.cloud_outlined;
    }
    return isDaytime ? Icons.wb_sunny_outlined : Icons.nightlight_round;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg1 = isDaytime ? scheme.primary : scheme.secondary;
    final bg2 = isDaytime ? scheme.primaryContainer : scheme.tertiaryContainer;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // was: withOpacity(0.85)
            colors: [bg1.withValues(alpha: 0.85), bg2.withValues(alpha: 0.85)],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // was: scheme.surface.withOpacity(0.25)
                color: scheme.surface.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, size: 36, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DefaultTextStyle(
                style: TextStyle(color: scheme.onPrimaryContainer),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$temperatureC°',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          condition,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (highC != null && lowC != null)
                          Text(
                            'H: $highC°  L: $lowC°',
                            // was: withOpacity(0.9)
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onPrimaryContainer.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (lastUpdated != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Diperbarui ${_fmt(lastUpdated!)}',
                        // was: withOpacity(0.8)
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
