import 'user.dart';

class Challenge {
  final String id;
  final String code;
  final String status;
  final int duration;
  final DateTime startDate;
  final DateTime? endDate;
  final User? creator;
  final User? opponent;
  final String? winner;

  Challenge({
    required this.id,
    required this.code,
    required this.status,
    this.duration = 30,
    required this.startDate,
    this.endDate,
    this.creator,
    this.opponent,
    this.winner,
  });

  int get remainingDays {
    if (endDate == null) return 0;
    if (status == 'finished') return 0;
    final diff = endDate!.difference(DateTime.now());
    return diff.inDays > 0 ? diff.inDays : 0;
  }

  bool get hasEnded {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] ?? json['_id'] ?? '',
      code: json['code'] ?? '',
      status: json['status'] ?? 'waiting',
      duration: json['duration'] ?? 30,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      creator: json['creator'] != null ? User.fromJson(json['creator']) : null,
      opponent: json['opponent'] != null ? User.fromJson(json['opponent']) : null,
      winner: json['winner'],
    );
  }
}
