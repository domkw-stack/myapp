import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  final List<LatLng> routePoints;
  final Position? currentPosition;

  const MapScreen({
    super.key,
    required this.routePoints,
    this.currentPosition,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;
  bool _followUser = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  LatLng get _centerPoint {
    if (widget.currentPosition != null) {
      return LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude);
    }
    if (widget.routePoints.isNotEmpty) return widget.routePoints.last;
    return const LatLng(24.7136, 46.6753); // الرياض كإحداثيات افتراضية
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مسار المشي'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_followUser ? Icons.gps_fixed : Icons.gps_not_fixed),
            onPressed: () {
              setState(() => _followUser = !_followUser);
              if (_followUser) {
                _mapController.move(_centerPoint, 16);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centerPoint,
              initialZoom: 16,
              onMapEvent: (event) {
                if (event is MapEventMove && event.source != MapEventSource.mapController) {
                  setState(() => _followUser = false);
                }
              },
            ),
            children: [
              // طبقة الخريطة المجانية - OpenStreetMap
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.walktracker.app',
              ),

              // المسار المقطوع
              if (widget.routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.routePoints,
                      color: theme.colorScheme.primary,
                      strokeWidth: 5,
                    ),
                  ],
                ),

              // نقطة البداية
              if (widget.routePoints.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.routePoints.first,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(Icons.flag, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),

              // الموقع الحالي
              if (widget.currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _centerPoint,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),

              // حقوق الخريطة
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // معلومات المسار
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _infoItem(Icons.route, '${widget.routePoints.length}', 'نقطة'),
                    const VerticalDivider(),
                    _infoItem(Icons.my_location, _followUser ? 'متتبع' : 'حر', 'الخريطة'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mapController.move(_centerPoint, 16);
          setState(() => _followUser = true);
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _infoItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
