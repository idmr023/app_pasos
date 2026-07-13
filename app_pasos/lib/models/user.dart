class User {
  final String id;
  final String username;
  final String displayName;
  final String role;
  final String avatar;

  User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? json['username'] ?? '',
      role: json['role'] ?? 'user',
      avatar: json['avatar'] ?? 'runner',
    );
  }
}
