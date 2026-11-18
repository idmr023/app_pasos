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

  /// Apuesta en pasos de cada participante (0 = sin apuesta).
  final int wager;

  /// none | open | paid | refunded
  final String wagerState;
  final String? wagerWinner;

  /// Saldo tras apostar (solo en la respuesta de crear/unirse).
  final int? balanceAfter;

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
    this.wager = 0,
    this.wagerState = 'none',
    this.wagerWinner,
    this.balanceAfter,
  });

  bool get hasWager => wager > 0;

  /// Bote para el ganador.
  int get pot => wager * 2;

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
      wager: json['wager'] is num ? (json['wager'] as num).toInt() : 0,
      wagerState: json['wagerState'] as String? ?? 'none',
      wagerWinner: json['wagerWinner']?.toString(),
      balanceAfter: json['balance'] is num ? (json['balance'] as num).toInt() : null,
    );
  }
}
