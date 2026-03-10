import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OSRM - مجاني - مسارات تتبع الشوارع الفعلية
class RoutingService {
  static final RoutingService instance = RoutingService._();
  RoutingService._();

  static const _base = 'https://router.project-osrm.org/route/v1/foot';

  /// مسار بين نقطتين يتبع الشوارع
  Future<List<LatLng>> getRoute(LatLng from, LatLng to) async {
    try {
      final url = '$_base/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';

      final res = await http.get(Uri.parse(url),
          headers: {'User-Agent': 'WalkTrackerApp/1.0'})
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return [from, to];
      final j = jsonDecode(res.body);
      if (j['code'] != 'Ok') return [from, to];

      final coords = j['routes'][0]['geometry']['coordinates'] as List;
      return coords.map((c) => LatLng(
        (c[1] as num).toDouble(),
        (c[0] as num).toDouble(),
      )).toList();
    } catch (_) {
      return [from, to];
    }
  }

  /// مسار دائري يتبع الشوارع بطول تقريبي
  Future<List<LatLng>> getCircularRoute(LatLng center, double targetMeters) async {
    try {
      final r = (targetMeters / 4) / 111320.0;
      // 4 نقاط حول المركز تشكل مربعاً
      final points = [
        center,
        LatLng(center.latitude + r, center.longitude + r),
        LatLng(center.latitude,     center.longitude + r * 2),
        LatLng(center.latitude - r, center.longitude + r),
        center,
      ];

      final coords = points.map((p) =>
          '${p.longitude},${p.latitude}').join(';');

      final res = await http.get(
          Uri.parse('$_base/$coords?overview=full&geometries=geojson'),
          headers: {'User-Agent': 'WalkTrackerApp/1.0'})
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return [];
      final j = jsonDecode(res.body);
      if (j['code'] != 'Ok') return [];

      final routeCoords = j['routes'][0]['geometry']['coordinates'] as List;
      return routeCoords.map((c) => LatLng(
        (c[1] as num).toDouble(),
        (c[0] as num).toDouble(),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  double routeDistanceMeters(List<LatLng> pts) {
    double total = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      final dlat = (pts[i+1].latitude  - pts[i].latitude)  * 111320;
      final dlng = (pts[i+1].longitude - pts[i].longitude) *
          111320 * math.cos(pts[i].latitude * math.pi / 180);
      total += math.sqrt(dlat * dlat + dlng * dlng);
    }
    return total;
  }
}
