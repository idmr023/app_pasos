class User {
  final String id;
  final String username;
  final String displayName;
  final String role;
  final String avatar;
  final int xp;
  final int level;
  final String title;

  User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.avatar,
    this.xp = 0,
    this.level = 0,
    this.title = '',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? json['username'] ?? '',
      role: json['role'] ?? 'user',
      avatar: json['avatar'] ?? 'runner',
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 0,
      title: json['title'] ?? '',
    );
  }

  User copyWith({
    String? id,
    String? username,
    String? displayName,
    String? role,
    String? avatar,
    int? xp,
    int? level,
    String? title,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      title: title ?? this.title,
    );
  }
}
