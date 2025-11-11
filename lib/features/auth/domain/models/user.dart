class User {
  final String id;
  final String userName;
  final String email;
  final String? fullName;
  final List<String> roles;

  User({
    required this.id,
    required this.userName,
    required this.email,
    this.fullName,
    required this.roles,
  });

  factory User.fromMap(Map<String, dynamic> json) {
    return User(
      id: (json['Id'] ?? json['id'] ?? '').toString(),
      userName: (json['UserName'] ?? json['userName'] ?? json['username'] ?? '')
          .toString(),
      email: (json['Email'] ?? json['email'] ?? '').toString(),
      fullName: (json['FullName'] ?? json['fullName'])?.toString(),
      roles: (json['Roles'] is List)
          ? List<String>.from(json['Roles'].map((e) => e.toString()))
          : (json['roles'] is List)
          ? List<String>.from(json['roles'].map((e) => e.toString()))
          : <String>[],
    );
  }
}
