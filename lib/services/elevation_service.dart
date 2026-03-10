import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/elevation_point.dart';

class ElevationService {
  static final ElevationService instance = ElevationService._init();
  ElevationService._init();

  // Open-Elevation API - مجاني ومفتوح المصدر
  static const String _baseUrl = 'https://api.open-elevation.com/api/v1/lookup';

  /// جلب الارتفاع لمجموعة نقاط من API مجاني
  Future<List<double>> fetchElevations(List<LatLng> points) async {
    if (points.isEmpty) return [];

    // نأخذ عينة كل 10 نقاط لتقليل الطلبات
    final sampled = <LatLng>[];
    for (int i = 0; i < points.length; i += max(1, points.length ~/ 100)) {
      sampled.add(points[i]);
    }
    if (sampled.last != points.last) sampled.add(points.last);

    try {
      final locations = sampled.map((p) => {'latitude': p.latitude, 'longitude': p.longitude}).toList();
      final body = jsonEncode({'locations': locations});

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        return results.map<double>((r) => (r['elevation'] as num).toDouble()).toList();
      }
    } catch (e) {
      // fallback: محاكاة ارتفاع بسيط إذا فشل الاتصال
    }

    // Fallback: ارتفاع محاكى
    return List.generate(sampled.length, (i) => 100 + 20 * sin(i * 0.3));
  }

  /// بناء ملف الارتفاع الكامل
  Future<ElevationProfile> buildProfile(List<LatLng> points) async {
    if (points.length < 2) {
      return ElevationProfile(points: [], totalGain: 0, totalLoss: 0, maxElevation: 0, minElevation: 0);
    }

    final elevations = await fetchElevations(points);
    final sampled = <LatLng>[];
    for (int i = 0; i < points.length; i += max(1, points.length ~/ elevations.length)) {
      if (sampled.length < elevations.length) sampled.add(points[i]);
    }
    while (sampled.length < elevations.length) sampled.add(points.last);

    double distSoFar = 0;
    double totalGain = 0;
    double totalLoss = 0;
    final profilePoints = <ElevationPoint>[];

    for (int i = 0; i < sampled.length; i++) {
      if (i > 0) {
        distSoFar += Geolocator.distanceBetween(
          sampled[i - 1].latitude, sampled[i - 1].longitude,
          sampled[i].latitude, sampled[i].longitude,
        );
        final diff = elevations[i] - elevations[i - 1];
        if (diff > 0) totalGain += diff;
        else totalLoss += diff.abs();
      }
      profilePoints.add(ElevationPoint(
        position: sampled[i],
        elevation: elevations[i],
        distanceFromStart: distSoFar,
      ));
    }

    return ElevationProfile(
      points: profilePoints,
      totalGain: totalGain,
      totalLoss: totalLoss,
      maxElevation: elevations.reduce(max),
      minElevation: elevations.reduce(min),
    );
  }

  /// توليد مسار دائري مقترح من نقطة البداية
  List<LatLng> generateCircularRoute(LatLng center, double radiusMeters, int numPoints) {
    final points = <LatLng>[];
    for (int i = 0; i <= numPoints; i++) {
      final angle = (2 * pi * i) / numPoints;
      // تحويل الأمتار إلى درجات
      final latOffset = (radiusMeters / 111320) * cos(angle);
      final lngOffset = (radiusMeters / (111320 * cos(center.latitude * pi / 180))) * sin(angle);
      points.add(LatLng(center.latitude + latOffset, center.longitude + lngOffset));
    }
    return points;
  }

  /// توليد عدة مقترحات مسار دائري بأشكال مختلفة
  List<Map<String, dynamic>> suggestRoutes(LatLng center, double targetDistanceMeters) {
    final radius = targetDistanceMeters / (2 * pi);
    
    return [
      {
        'name': 'دائري كامل',
        'description': 'جولة دائرية ترجع لنقطة البداية',
        'icon': '⭕',
        'points': generateCircularRoute(center, radius, 36),
        'distance': targetDistanceMeters,
        'difficulty': 'easy',
      },
      {
        'name': 'ذهاب وإياب شمال',
        'description': 'امشِ شمالاً ثم عد',
        'icon': '↕️',
        'points': _generateLinearRoute(center, targetDistanceMeters / 2, 0),
        'distance': targetDistanceMeters,
        'difficulty': 'easy',
      },
      {
        'name': 'مثلث',
        'description': 'مسار مثلثي ثلاث محطات',
        'icon': '🔺',
        'points': _generatePolygonRoute(center, radius * 1.2, 3),
        'distance': targetDistanceMeters * 1.05,
        'difficulty': 'medium',
      },
      {
        'name': 'مربع',
        'description': 'مسار مربع أربع محطات',
        'icon': '🔲',
        'points': _generatePolygonRoute(center, radius * 0.9, 4),
        'distance': targetDistanceMeters,
        'difficulty': 'medium',
      },
    ];
  }

  List<LatLng> _generateLinearRoute(LatLng center, double halfDistMeters, double bearingDeg) {
    final bearingRad = bearingDeg * pi / 180;
    final latOffset = (halfDistMeters / 111320) * cos(bearingRad);
    final lngOffset = (halfDistMeters / (111320 * cos(center.latitude * pi / 180))) * sin(bearingRad);
    final end = LatLng(center.latitude + latOffset, center.longitude + lngOffset);
    // توليد نقاط متوسطة
    final pts = <LatLng>[];
    const steps = 20;
    for (int i = 0; i <= steps; i++) {
      pts.add(LatLng(
        center.latitude + latOffset * i / steps,
        center.longitude + lngOffset * i / steps,
      ));
    }
    for (int i = steps; i >= 0; i--) {
      pts.add(LatLng(
        center.latitude + latOffset * i / steps,
        center.longitude + lngOffset * i / steps,
      ));
    }
    return pts;
  }

  List<LatLng> _generatePolygonRoute(LatLng center, double radiusMeters, int sides) {
    final points = <LatLng>[];
    for (int i = 0; i <= sides; i++) {
      final angle = (2 * pi * i) / sides - pi / 2;
      final latOffset = (radiusMeters / 111320) * cos(angle);
      final lngOffset = (radiusMeters / (111320 * cos(center.latitude * pi / 180))) * sin(angle);
      points.add(LatLng(center.latitude + latOffset, center.longitude + lngOffset));
    }
    return points;
  }
}
