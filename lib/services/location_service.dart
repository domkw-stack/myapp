import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static final LocationService instance = LocationService._init();
  LocationService._init();

  StreamController<Position>? _positionController;
  Stream<Position>? _positionStream;
  StreamSubscription<Position>? _subscription;

  final List<LatLng> _routePoints = [];
  double _totalDistance = 0.0;
  Position? _lastPosition;
  DateTime? _startTime;
  int _stepCount = 0;

  // Getters
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  double get totalDistance => _totalDistance;
  int get stepCount => _stepCount;
  double get calories => _stepCount * 0.04; // تقريبي

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      return null;
    }
  }

  void startTracking(Function(Position) onPosition) {
    _routePoints.clear();
    _totalDistance = 0.0;
    _lastPosition = null;
    _startTime = DateTime.now();
    _stepCount = 0;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // تحديث كل 5 أمتار
    );

    _subscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      if (_lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        
        // تصفية القفزات الكبيرة (أكثر من 50 متر في ثانية)
        final timeDiff = position.timestamp.difference(_lastPosition!.timestamp).inSeconds;
        if (timeDiff > 0 && distance / timeDiff < 50) {
          _totalDistance += distance;
          // تقدير عدد الخطوات (متوسط خطوة = 0.75 متر)
          _stepCount += (distance / 0.75).round();
        }
      }

      _routePoints.add(LatLng(position.latitude, position.longitude));
      _lastPosition = position;
      onPosition(position);
    });
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
  }

  double calculateSpeed(Position? position) {
    if (position == null) return 0.0;
    return position.speed * 3.6; // تحويل م/ث إلى كم/س
  }

  double calculateAvgSpeed() {
    if (_startTime == null || _totalDistance == 0) return 0.0;
    final duration = DateTime.now().difference(_startTime!).inSeconds;
    if (duration == 0) return 0.0;
    return (_totalDistance / duration) * 3.6; // كم/س
  }

  String encodeRoutePoints() {
    if (_routePoints.isEmpty) return '[]';
    final points = _routePoints.map((p) => '${p.latitude},${p.longitude}').join(';');
    return points;
  }

  static List<LatLng> decodeRoutePoints(String encoded) {
    if (encoded == '[]' || encoded.isEmpty) return [];
    return encoded.split(';').map((p) {
      final parts = p.split(',');
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    }).toList();
  }
}
