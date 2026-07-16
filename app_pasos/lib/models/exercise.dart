class Exercise {
  final String id;
  final String name;
  final String category;
  final String imageUrl;
  final int defaultSets;
  final String defaultReps;
  final int restTime;
  final String description;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    this.imageUrl = '',
    this.defaultSets = 3,
    this.defaultReps = '10',
    this.restTime = 60,
    this.description = '',
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'strength',
      imageUrl: json['imageUrl'] ?? '',
      defaultSets: json['defaultSets'] ?? 3,
      defaultReps: json['defaultReps'] ?? '10',
      restTime: json['restTime'] ?? 60,
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'category': category,
    'imageUrl': imageUrl,
    'defaultSets': defaultSets,
    'defaultReps': defaultReps,
    'restTime': restTime,
    'description': description,
  };
}