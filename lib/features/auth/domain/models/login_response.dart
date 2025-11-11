import 'user.dart';

class LoginResponse {
  final bool success;
  final String message;
  final String token;
  final DateTime? expiresAt;
  final String? refreshToken;
  final DateTime? refreshExpiresAt;
  final User? user;

  LoginResponse({
    required this.success,
    required this.message,
    required this.token,
    this.expiresAt,
    this.refreshToken,
    this.refreshExpiresAt,
    this.user,
  });

  factory LoginResponse.fromMap(Map<String, dynamic> map) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    return LoginResponse(
      success: map['Success'] == true || map['success'] == true,
      message: (map['Message'] ?? map['message'] ?? '').toString(),
      token: (map['Token'] ?? map['token'] ?? '').toString(),
      expiresAt: parseDt(map['ExpiresAt'] ?? map['expiresAt']),
      refreshToken: (map['RefreshToken'] ?? map['refreshToken'] ?? '')
          .toString(),
      refreshExpiresAt: parseDt(
        map['RefreshExpiresAt'] ?? map['refreshExpiresAt'],
      ),
      user: (map['User'] ?? map['user']) is Map<String, dynamic>
          ? User.fromMap((map['User'] ?? map['user']) as Map<String, dynamic>)
          : null,
    );
  }
}
