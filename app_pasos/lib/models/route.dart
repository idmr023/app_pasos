// model definitions

class Coordinate {
  final double lat;
  final double lng;
  final double elevation;
  final String timestamp;
  final int heartRate;

  Coordinate({
    required this.lat,
    required this.lng,
    this.elevation = 0,
    this.timestamp = '',
    this.heartRate = 0,
  });

  factory Coordinate.fromJson(Map<String, dynamic> json) {
    return Coordinate(
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      elevation: (json['elevation'] ?? 0).toDouble(),
      timestamp: json['timestamp'] ?? '',
      heartRate: json['heartRate'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'elevation': elevation,
        'timestamp': timestamp,
        'heartRate': heartRate,
      };
}

class RouteDesign {
  final String routeColor;
  final String backgroundColor;
  final String fontFamily;
  final int lineWidth;
  final List<String> showStats;
  final String statsLayout;
  final String lineStyle;
  final bool showElevation;

  RouteDesign({
    this.routeColor = '#3B82F6',
    this.backgroundColor = '#0F172A',
    this.fontFamily = 'Montserrat',
    this.lineWidth = 4,
    this.showStats = const [],
    this.statsLayout = 'bottom-bar',
    this.lineStyle = 'solid',
    this.showElevation = false,
  });

  factory RouteDesign.fromJson(Map<String, dynamic> json) {
    return RouteDesign(
      routeColor: json['routeColor'] ?? '#3B82F6',
      backgroundColor: json['backgroundColor'] ?? '#0F172A',
      fontFamily: json['fontFamily'] ?? 'Montserrat',
      lineWidth: json['lineWidth'] ?? 4,
      showStats: List<String>.from(json['showStats'] ?? []),
      statsLayout: json['statsLayout'] ?? 'bottom-bar',
      lineStyle: json['lineStyle'] ?? 'solid',
      showElevation: json['showElevation'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'routeColor': routeColor,
        'backgroundColor': backgroundColor,
        'fontFamily': fontFamily,
        'lineWidth': lineWidth,
        'showStats': showStats,
        'statsLayout': statsLayout,
        'lineStyle': lineStyle,
        'showElevation': showElevation,
      };
}

class UserRoute {
  final String id;
  final String userId;
  final String title;
  final String source;
  final int? stravaActivityId;
  final List<Coordinate> coordinates;
  final int distance;
  final int duration;
  final int elevationGain;
  final int averagePace;
  final int averageHeartRate;
  final int maxHeartRate;
  final int calories;
  final String caloriesSource;
  final String activityType;
  final DateTime? startDate;
  final RouteDesign? design;
  final DateTime? createdAt;

  UserRoute({
    required this.id,
    required this.userId,
    required this.title,
    required this.source,
    this.stravaActivityId,
    required this.coordinates,
    required this.distance,
    required this.duration,
    required this.elevationGain,
    required this.averagePace,
    required this.averageHeartRate,
    required this.maxHeartRate,
    required this.calories,
    required this.caloriesSource,
    required this.activityType,
    this.startDate,
    this.design,
    this.createdAt,
  });

  factory UserRoute.fromJson(Map<String, dynamic> json) {
    var rawCoords = json['coordinates'] as List? ?? [];
    List<Coordinate> coords = rawCoords.map((c) => Coordinate.fromJson(c)).toList();

    return UserRoute(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['user'] is String ? json['user'] : (json['user']?['_id'] ?? ''),
      title: json['title'] ?? 'Ruta sin título',
      source: json['source'] ?? 'manual',
      stravaActivityId: json['stravaActivityId'],
      coordinates: coords,
      distance: json['distance'] ?? 0,
      duration: json['duration'] ?? 0,
      elevationGain: json['elevationGain'] ?? 0,
      averagePace: json['averagePace'] ?? 0,
      averageHeartRate: json['averageHeartRate'] ?? 0,
      maxHeartRate: json['maxHeartRate'] ?? 0,
      calories: json['calories'] ?? 0,
      caloriesSource: json['caloriesSource'] ?? (((json['calories'] ?? 0) > 0) ? 'detail' : 'missing'),
      activityType: json['activityType'] ?? 'run',
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      design: json['design'] != null ? RouteDesign.fromJson(json['design']) : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }
}
