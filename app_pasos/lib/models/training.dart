// Modelos del módulo Entrenamiento (ver docs/TRAINING.md y backend/routes/training.js).

double _d(dynamic v) => v is num ? v.toDouble() : 0;
int _i(dynamic v) => v is num ? v.round() : 0;
int? _iOrNull(dynamic v) => v is num ? v.round() : null;
DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

String formatPace(num? secPerKm) {
  if (secPerKm == null || secPerKm <= 0) return '--';
  final s = secPerKm.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}/km';
}

String formatDuration(num? seconds) {
  if (seconds == null || seconds <= 0) return '--';
  final s = seconds.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final r = s % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  return '$m:${r.toString().padLeft(2, '0')}';
}

const Map<String, String> sessionTypeLabels = {
  'auto': 'Automático',
  'recovery': 'Recuperación',
  'easy': 'Rodaje suave',
  'long': 'Tirada larga',
  'tempo': 'Tempo / umbral',
  'intervals': 'Series',
  'race': 'Competición',
  'other': 'Otro',
};

const Map<String, String> sportLabels = {
  'run': 'Carrera',
  'trail': 'Trail',
  'ride': 'Bici',
  'walk': 'Caminata',
  'hike': 'Senderismo',
  'swim': 'Natación',
  'other': 'Otro',
};

class TrainingSplit {
  final int index;
  final double distance;
  final double movingTime;
  final double elevationDiff;
  final int averageHeartRate;

  TrainingSplit.fromJson(Map<String, dynamic> j)
      : index = _i(j['index']),
        distance = _d(j['distance']),
        movingTime = _d(j['movingTime']),
        elevationDiff = _d(j['elevationDiff']),
        averageHeartRate = _i(j['averageHeartRate']);

  double get pace => distance > 0 ? movingTime / (distance / 1000) : 0;
}

class TrainingLap {
  final int index;
  final String name;
  final double distance;
  final double movingTime;
  final int averageHeartRate;

  TrainingLap.fromJson(Map<String, dynamic> j)
      : index = _i(j['index']),
        name = j['name']?.toString() ?? '',
        distance = _d(j['distance']),
        movingTime = _d(j['movingTime']),
        averageHeartRate = _i(j['averageHeartRate']);

  double get pace => distance > 0 ? movingTime / (distance / 1000) : 0;
}

class TrainingInsight {
  final String level; // good | warn | info
  final String text;
  TrainingInsight.fromJson(Map<String, dynamic> j)
      : level = j['level']?.toString() ?? 'info',
        text = j['text']?.toString() ?? '';
}

class SessionAnalysis {
  final String type;
  final double load;
  final String loadSource;
  final double pace;
  final double? hrPercentMax;
  final double? efficiency;
  final List<int>? zonePercent;
  final Map<String, dynamic>? splits;
  final Map<String, dynamic>? comparison;
  final List<TrainingInsight> insights;

  SessionAnalysis.fromJson(Map<String, dynamic> j)
      : type = j['type']?.toString() ?? 'other',
        load = _d(j['load']),
        loadSource = j['loadSource']?.toString() ?? 'none',
        pace = _d(j['pace']),
        hrPercentMax = j['hrPercentMax'] is num ? (j['hrPercentMax'] as num).toDouble() : null,
        efficiency = j['efficiency'] is num ? (j['efficiency'] as num).toDouble() : null,
        zonePercent = (j['zones']?['percent'] as List?)?.map(_i).toList(),
        splits = j['splits'] as Map<String, dynamic>?,
        comparison = j['comparison'] as Map<String, dynamic>?,
        insights = ((j['insights'] as List?) ?? [])
            .map((e) => TrainingInsight.fromJson(e as Map<String, dynamic>))
            .toList();
}

class TrainingSession {
  final String id;
  final String source;
  final String title;
  final String sport;
  final DateTime startDate;
  final double distance;
  final int movingTime;
  final int elevationGain;
  final int averageHeartRate;
  final int maxHeartRate;
  final int averageCadence;
  final int calories;
  final String sessionType;
  final int? rpe;
  final int? feeling;
  final String notes;
  final List<TrainingSplit> splits;
  final List<TrainingLap> laps;
  final SessionAnalysis? analysis;

  TrainingSession({
    required this.id,
    required this.source,
    required this.title,
    required this.sport,
    required this.startDate,
    required this.distance,
    required this.movingTime,
    required this.elevationGain,
    required this.averageHeartRate,
    required this.maxHeartRate,
    required this.averageCadence,
    required this.calories,
    required this.sessionType,
    required this.rpe,
    required this.feeling,
    required this.notes,
    required this.splits,
    required this.laps,
    required this.analysis,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> j) => TrainingSession(
        id: j['_id']?.toString() ?? '',
        source: j['source']?.toString() ?? 'manual',
        title: j['title']?.toString() ?? 'Entrenamiento',
        sport: j['sport']?.toString() ?? 'run',
        startDate: _date(j['startDate']) ?? DateTime.now(),
        distance: _d(j['distance']),
        movingTime: _i(j['movingTime']),
        elevationGain: _i(j['elevationGain']),
        averageHeartRate: _i(j['averageHeartRate']),
        maxHeartRate: _i(j['maxHeartRate']),
        averageCadence: _i(j['averageCadence']),
        calories: _i(j['calories']),
        sessionType: j['sessionType']?.toString() ?? 'auto',
        rpe: _iOrNull(j['rpe']),
        feeling: _iOrNull(j['feeling']),
        notes: j['notes']?.toString() ?? '',
        splits: ((j['splits'] as List?) ?? [])
            .map((e) => TrainingSplit.fromJson(e as Map<String, dynamic>))
            .toList(),
        laps: ((j['laps'] as List?) ?? [])
            .map((e) => TrainingLap.fromJson(e as Map<String, dynamic>))
            .toList(),
        analysis: j['analysis'] is Map<String, dynamic>
            ? SessionAnalysis.fromJson(j['analysis'] as Map<String, dynamic>)
            : null,
      );

  double get distanceKm => distance / 1000;
  String get effectiveType => analysis?.type ?? sessionType;
}

class StravaActivityItem {
  final int id;
  final String name;
  final String sport;
  final DateTime? startDate;
  final double distance;
  final int movingTime;
  final int averageHeartRate;
  final bool imported;
  final String? sessionId;

  StravaActivityItem.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = j['name']?.toString() ?? 'Actividad',
        sport = j['sport']?.toString() ?? 'other',
        startDate = _date(j['startDate']),
        distance = _d(j['distance']),
        movingTime = _i(j['movingTime']),
        averageHeartRate = _i(j['averageHeartRate']),
        imported = j['imported'] == true,
        sessionId = j['sessionId']?.toString();
}

class TrainingGoal {
  final String name;
  final double? distanceKm;
  final int? targetTimeSec;
  final DateTime? date;

  const TrainingGoal({this.name = '', this.distanceKm, this.targetTimeSec, this.date});

  factory TrainingGoal.fromJson(Map<String, dynamic> j) => TrainingGoal(
        name: j['name']?.toString() ?? '',
        distanceKm: j['distanceKm'] is num ? (j['distanceKm'] as num).toDouble() : null,
        targetTimeSec: _iOrNull(j['targetTimeSec']),
        date: _date(j['date']),
      );

  bool get isSet => distanceKm != null && distanceKm! > 0;

  Map<String, dynamic> toJson() => {
        'name': name,
        'distanceKm': distanceKm,
        'targetTimeSec': targetTimeSec,
        'date': date?.toUtc().toIso8601String(),
      };
}

class TrainingProfile {
  final int? maxHeartRate;
  final int? restingHeartRate;
  final int weeklySessions;
  final TrainingGoal? goal;

  const TrainingProfile({this.maxHeartRate, this.restingHeartRate, this.weeklySessions = 4, this.goal});

  factory TrainingProfile.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const TrainingProfile();
    final goal = j['goal'] is Map<String, dynamic> ? TrainingGoal.fromJson(j['goal']) : null;
    return TrainingProfile(
      maxHeartRate: _iOrNull(j['maxHeartRate']),
      restingHeartRate: _iOrNull(j['restingHeartRate']),
      weeklySessions: _iOrNull(j['weeklySessions']) ?? 4,
      goal: goal != null && goal.isSet ? goal : null,
    );
  }
}

class TrainingWeek {
  final DateTime weekStart;
  final double distanceKm;
  final int durationMin;
  final int load;
  final int sessions;
  final double longestRunKm;
  final bool current;

  TrainingWeek.fromJson(Map<String, dynamic> j)
      : weekStart = DateTime.tryParse(j['weekStart']?.toString() ?? '') ?? DateTime.now(),
        distanceKm = _d(j['distanceKm']),
        durationMin = _i(j['durationMin']),
        load = _i(j['load']),
        sessions = _i(j['sessions']),
        longestRunKm = _d(j['longestRunKm']),
        current = j['current'] == true;
}

class PlannedSession {
  final String type;
  final double distanceKm;
  final String pace;
  final String description;

  PlannedSession.fromJson(Map<String, dynamic> j)
      : type = j['type']?.toString() ?? 'easy',
        distanceKm = _d(j['distanceKm']),
        pace = j['pace']?.toString() ?? '',
        description = j['description']?.toString() ?? '';
}

class TrainingSummary {
  final List<TrainingWeek> weeks;
  final Map<String, dynamic> load;
  final Map<String, dynamic>? fitness;
  final Map<String, dynamic>? intensity;
  final Map<String, dynamic>? efficiency;
  final Map<String, dynamic>? goal;
  final Map<String, dynamic> recommendation;
  final List<PlannedSession> plan;
  final Map<String, dynamic> heartRate;
  final int totalSessions;

  TrainingSummary.fromJson(Map<String, dynamic> j)
      : weeks = ((j['weeks'] as List?) ?? [])
            .map((e) => TrainingWeek.fromJson(e as Map<String, dynamic>))
            .toList(),
        load = (j['load'] as Map<String, dynamic>?) ?? {},
        fitness = j['fitness'] as Map<String, dynamic>?,
        intensity = j['intensity'] as Map<String, dynamic>?,
        efficiency = j['efficiency'] as Map<String, dynamic>?,
        goal = j['goal'] as Map<String, dynamic>?,
        recommendation = (j['recommendation'] as Map<String, dynamic>?) ?? {},
        plan = (((j['recommendation'] as Map?)?['plan'] as List?) ?? [])
            .map((e) => PlannedSession.fromJson(e as Map<String, dynamic>))
            .toList(),
        heartRate = (j['heartRate'] as Map<String, dynamic>?) ?? {},
        totalSessions = _i((j['totals'] as Map?)?['sessions']);
}
