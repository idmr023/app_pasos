import 'user.dart';

class Challenge {
  final String id;
  final String code;
  final String status;
  final DateTime startDate;
  final User? creator;
  final User? opponent;

  Challenge({
    required this.id,
    required this.code,
    required this.status,
    required this.startDate,
    this.creator,
    this.opponent,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] ?? json['_id'] ?? '',
      code: json['code'] ?? '',
      status: json['status'] ?? 'waiting',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      creator: json['creator'] != null ? User.fromJson(json['creator']) : null,
      opponent: json['opponent'] != null ? User.fromJson(json['opponent']) : null,
    );
  }
}
