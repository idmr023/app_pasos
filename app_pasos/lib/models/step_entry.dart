class StepEntry {
  final String id;
  final String userId;
  final String challengeId;
  final DateTime date;
  final int steps;
  final String? username;
  final String? displayName;
  final String? avatar;

  StepEntry({
    required this.id,
    required this.userId,
    required this.challengeId,
    required this.date,
    required this.steps,
    this.username,
    this.displayName,
    this.avatar,
  });

  factory StepEntry.fromJson(Map<String, dynamic> json) {
    return StepEntry(
      id: json['_id'] ?? '',
      userId: json['user'] is Map ? (json['user']['id'] ?? json['user']['_id'] ?? '') : (json['user'] ?? ''),
      challengeId: json['challenge'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      steps: json['steps'] ?? 0,
      username: json['user'] is Map ? json['user']['username'] : null,
      displayName: json['user'] is Map ? json['user']['displayName'] : null,
      avatar: json['user'] is Map ? json['user']['avatar'] : null,
    );
  }
}

class CalendarDay {
  final String date;
  final int day;
  final List<CalendarEntry> entries;

  CalendarDay({
    required this.date,
    required this.day,
    required this.entries,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    return CalendarDay(
      date: json['date'] ?? '',
      day: json['day'] ?? 0,
      entries: (json['entries'] as List?)
          ?.map((e) => CalendarEntry.fromJson(e))
          .toList() ?? [],
    );
  }
}

class CalendarEntry {
  final String userId;
  final String username;
  final String displayName;
  final String avatar;
  final int steps;

  CalendarEntry({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.steps,
  });

  factory CalendarEntry.fromJson(Map<String, dynamic> json) {
    return CalendarEntry(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      avatar: json['avatar'] ?? '',
      steps: json['steps'] ?? 0,
    );
  }
}
