class SavedRoute {
  final int? id;
  final String name;
  final String description;
  final String routePoints; // encoded "lat,lng;lat,lng;..."
  final double distanceMeters;
  final double? elevationGainMeters;
  final String difficulty; // easy, medium, hard
  final DateTime createdAt;
  final bool isFavorite;
  final int usageCount;
  final String? thumbnailColor; // للعرض بدون صورة

  SavedRoute({
    this.id,
    required this.name,
    required this.description,
    required this.routePoints,
    required this.distanceMeters,
    this.elevationGainMeters,
    required this.difficulty,
    required this.createdAt,
    this.isFavorite = false,
    this.usageCount = 0,
    this.thumbnailColor,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'routePoints': routePoints,
    'distanceMeters': distanceMeters,
    'elevationGainMeters': elevationGainMeters,
    'difficulty': difficulty,
    'createdAt': createdAt.toIso8601String(),
    'isFavorite': isFavorite ? 1 : 0,
    'usageCount': usageCount,
    'thumbnailColor': thumbnailColor,
  };

  factory SavedRoute.fromMap(Map<String, dynamic> m) => SavedRoute(
    id: m['id'],
    name: m['name'],
    description: m['description'],
    routePoints: m['routePoints'],
    distanceMeters: m['distanceMeters'],
    elevationGainMeters: m['elevationGainMeters'],
    difficulty: m['difficulty'],
    createdAt: DateTime.parse(m['createdAt']),
    isFavorite: m['isFavorite'] == 1,
    usageCount: m['usageCount'] ?? 0,
    thumbnailColor: m['thumbnailColor'],
  );

  SavedRoute copyWith({
    String? name,
    String? description,
    bool? isFavorite,
    int? usageCount,
    double? elevationGainMeters,
  }) => SavedRoute(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    routePoints: routePoints,
    distanceMeters: distanceMeters,
    elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
    difficulty: difficulty,
    createdAt: createdAt,
    isFavorite: isFavorite ?? this.isFavorite,
    usageCount: usageCount ?? this.usageCount,
    thumbnailColor: thumbnailColor,
  );

  String get distanceFormatted {
    if (distanceMeters >= 1000) return '${(distanceMeters / 1000).toStringAsFixed(2)} كم';
    return '${distanceMeters.toStringAsFixed(0)} م';
  }

  String get difficultyLabel {
    switch (difficulty) {
      case 'easy': return 'سهل';
      case 'medium': return 'متوسط';
      case 'hard': return 'صعب';
      default: return difficulty;
    }
  }

  String get difficultyEmoji {
    switch (difficulty) {
      case 'easy': return '🟢';
      case 'medium': return '🟡';
      case 'hard': return '🔴';
      default: return '⚪';
    }
  }
}
