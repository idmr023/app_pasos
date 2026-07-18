class Exercise {
  final String id;
  final String name;
  final String nameSpanish;
  final String category;
  final String imageUrl;
  final int defaultSets;
  final String defaultReps;
  final int restTime;
  final String description;
  final String videoUrl;
  final String muscle;
  final String equipment;
  final String difficulty;

  String get displayName => nameSpanish.isNotEmpty ? nameSpanish : name;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    this.nameSpanish = '',
    this.imageUrl = '',
    this.defaultSets = 3,
    this.defaultReps = '10',
    this.restTime = 60,
    this.description = '',
    this.videoUrl = '',
    this.muscle = '',
    this.equipment = '',
    this.difficulty = '',
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      nameSpanish: json['nameSpanish'] ?? '',
      category: json['category'] ?? 'strength',
      imageUrl: json['imageUrl'] ?? '',
      defaultSets: json['defaultSets'] ?? 3,
      defaultReps: json['defaultReps'] ?? '10',
      restTime: json['restTime'] ?? 60,
      description: json['description'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      muscle: json['muscle'] ?? '',
      equipment: json['equipment'] ?? '',
      difficulty: json['difficulty'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'nameSpanish': nameSpanish,
    'category': category,
    'imageUrl': imageUrl,
    'defaultSets': defaultSets,
    'defaultReps': defaultReps,
    'restTime': restTime,
    'description': description,
    'videoUrl': videoUrl,
    'muscle': muscle,
    'equipment': equipment,
    'difficulty': difficulty,
  };
}
