import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();
  static final Logger logger = Logger(
    printer: PrettyPrinter(
      lineLength: 80,
      methodCount: 0,
      errorMethodCount: 5,
      printEmojis: false,
      noBoxingByDefault: true,
    ),
    level: Level.debug,
  );

  static String maskToken(String? token) {
    if (token == null || token.isEmpty) return 'null';
    if (token.length <= 10) return '***${token.substring(token.length - 4)}';
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }
}
