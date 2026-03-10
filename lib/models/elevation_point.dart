import 'package:latlong2/latlong.dart';

class ElevationPoint {
  final LatLng position;
  final double elevation; // بالأمتار
  final double distanceFromStart; // بالأمتار

  const ElevationPoint({
    required this.position,
    required this.elevation,
    required this.distanceFromStart,
  });
}

class ElevationProfile {
  final List<ElevationPoint> points;
  final double totalGain;
  final double totalLoss;
  final double maxElevation;
  final double minElevation;

  ElevationProfile({
    required this.points,
    required this.totalGain,
    required this.totalLoss,
    required this.maxElevation,
    required this.minElevation,
  });

  String get gainFormatted => '↑ ${totalGain.toStringAsFixed(0)} م';
  String get lossFormatted => '↓ ${totalLoss.toStringAsFixed(0)} م';

  String get difficultyFromElevation {
    if (totalGain < 50) return 'easy';
    if (totalGain < 200) return 'medium';
    return 'hard';
  }
}
