class User {
  final String id;
  final String username;
  final String displayName;
  final String role;
  final String avatar;
  final int xp;
  final int level;
  final String title;
  final double weight;
  final double height;
  final String goal;

  User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.avatar,
    this.xp = 0,
    this.level = 0,
    this.title = '',
    this.weight = 0,
    this.height = 0,
    this.goal = 'general',
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
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
      goal: json['goal'] ?? 'general',
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
    double? weight,
    double? height,
    String? goal,
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
      weight: weight ?? this.weight,
      height: height ?? this.height,
      goal: goal ?? this.goal,
    );
  }
}
