class WalkSession {
  final int?     id;
  final DateTime date;
  final int      duration;     // ثواني
  final double   distance;     // متر
  final int      steps;
  final int      calories;
  final double   avgSpeed;     // كم/س
  final String   routePoints;  // encoded
  final double   targetDistance;
  final String   tripType;

  const WalkSession({
    this.id,
    required this.date,
    required this.duration,
    required this.distance,
    required this.steps,
    required this.calories,
    required this.avgSpeed,
    required this.routePoints,
    required this.targetDistance,
    required this.tripType,
  });

  WalkSession copyWith({int? id}) => WalkSession(
    id:             id ?? this.id,
    date:           date,
    duration:       duration,
    distance:       distance,
    steps:          steps,
    calories:       calories,
    avgSpeed:       avgSpeed,
    routePoints:    routePoints,
    targetDistance: targetDistance,
    tripType:       tripType,
  );

  Map<String, dynamic> toMap() => {
    'id':             id,
    'date':           date.toIso8601String(),
    'duration':       duration,
    'distance':       distance,
    'steps':          steps,
    'calories':       calories,
    'avgSpeed':       avgSpeed,
    'routePoints':    routePoints,
    'targetDistance': targetDistance,
    'tripType':       tripType,
  };

  factory WalkSession.fromMap(Map<String, dynamic> m) => WalkSession(
    id:             m['id'],
    date:           DateTime.parse(m['date'] ?? m['startTime'] ?? DateTime.now().toIso8601String()),
    duration:       m['duration'] ?? 0,
    distance:       (m['distance'] ?? m['distanceCovered'] ?? 0.0).toDouble(),
    steps:          m['steps'] ?? m['stepCount'] ?? 0,
    calories:       (m['calories'] ?? 0).toInt(),
    avgSpeed:       (m['avgSpeed'] ?? 0.0).toDouble(),
    routePoints:    m['routePoints'] ?? '',
    targetDistance: (m['targetDistance'] ?? 0.0).toDouble(),
    tripType:       m['tripType'] ?? 'free',
  );

  String get durationFormatted {
    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    final s = duration % 60;
    if (h > 0) return '${h}س ${m}د';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  String get distanceFormatted => distance >= 1000
      ? '${(distance / 1000).toStringAsFixed(2)} كم'
      : '${distance.toStringAsFixed(0)} م';
}
