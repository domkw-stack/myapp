import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/saved_route.dart';
import '../services/elevation_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class RouteSuggestionsScreen extends StatefulWidget {
  final double targetDistanceMeters;
  const RouteSuggestionsScreen({super.key, required this.targetDistanceMeters});

  @override
  State<RouteSuggestionsScreen> createState() => _RouteSuggestionsScreenState();
}

class _RouteSuggestionsScreenState extends State<RouteSuggestionsScreen> {
  Position? _currentPosition;
  List<Map<String, dynamic>> _suggestions = [];
  int _selectedIndex = 0;
  bool _loading = true;
  bool _saving = false;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loading = true);
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos == null) throw Exception('لم يتمكن من تحديد الموقع');
      _currentPosition = pos;
      final center = LatLng(pos.latitude, pos.longitude);
      final suggestions = ElevationService.instance.suggestRoutes(center, widget.targetDistanceMeters);
      setState(() { _suggestions = suggestions; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _saveRoute(Map<String, dynamic> suggestion) async {
    setState(() => _saving = true);
    final points = suggestion['points'] as List<LatLng>;
    final encoded = points.map((p) => '${p.latitude},${p.longitude}').join(';');
    final colors = ['teal', 'blue', 'orange', 'purple'];

    final route = SavedRoute(
      name: suggestion['name'] as String,
      description: suggestion['description'] as String,
      routePoints: encoded,
      distanceMeters: (suggestion['distance'] as double),
      difficulty: suggestion['difficulty'] as String,
      createdAt: DateTime.now(),
      thumbnailColor: colors[_selectedIndex % colors.length],
    );

    await DatabaseService.instance.insertSavedRoute(route);
    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [Icon(Icons.check, color: Colors.white), SizedBox(width: 8), Text('تم حفظ المسار!')]),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مسارات مقترحة'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSuggestions),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جارٍ توليد المسارات المقترحة...'),
                  SizedBox(height: 8),
                  Text('يتم حساب المسافة من موقعك الحالي',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : Column(
              children: [
                // بطاقات الاختيار
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    itemCount: _suggestions.length,
                    itemBuilder: (_, i) => _buildSuggestionChip(i, theme),
                  ),
                ),
                // الخريطة
                Expanded(child: _buildMapPreview(theme)),
                // تفاصيل المسار المختار
                _buildSelectedRouteDetails(theme),
              ],
            ),
    );
  }

  Widget _buildSuggestionChip(int index, ThemeData theme) {
    final s = _suggestions[index];
    final selected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        final points = s['points'] as List<LatLng>;
        if (points.isNotEmpty) {
          double latSum = 0, lngSum = 0;
          for (final p in points) { latSum += p.latitude; lngSum += p.longitude; }
          _mapController.move(LatLng(latSum / points.length, lngSum / points.length), 15);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(left: 8),
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 8)] : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(s['icon'] as String, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(s['name'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected ? theme.colorScheme.primary : null,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapPreview(ThemeData theme) {
    if (_suggestions.isEmpty || _currentPosition == null) {
      return const Center(child: Text('لا توجد مسارات مقترحة'));
    }
    final current = _suggestions[_selectedIndex];
    final points = current['points'] as List<LatLng>;
    final center = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: center, initialZoom: 15),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.walktracker.app',
        ),
        // جميع المسارات باهتة
        PolylineLayer(
          polylines: _suggestions.asMap().entries.where((e) => e.key != _selectedIndex).map((e) =>
            Polyline(points: e.value['points'] as List<LatLng>, color: Colors.grey.withOpacity(0.3), strokeWidth: 2)
          ).toList(),
        ),
        // المسار المختار
        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                color: theme.colorScheme.primary,
                strokeWidth: 5,
                borderColor: Colors.white,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        // موقعك الحالي
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 48, height: 48,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 10)],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  Widget _buildSelectedRouteDetails(ThemeData theme) {
    if (_suggestions.isEmpty) return const SizedBox();
    final s = _suggestions[_selectedIndex];
    final dist = s['distance'] as double;
    final distLabel = dist >= 1000 ? '${(dist / 1000).toStringAsFixed(2)} كم' : '${dist.toStringAsFixed(0)} م';
    final diff = s['difficulty'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(s['icon'] as String, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['name'] as String, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(s['description'] as String, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _detailChip(Icons.straighten, distLabel),
              const SizedBox(width: 8),
              _detailChip(Icons.flag, diff == 'easy' ? 'سهل 🟢' : diff == 'medium' ? 'متوسط 🟡' : 'صعب 🔴'),
              const SizedBox(width: 8),
              _detailChip(Icons.directions_walk,
                  '~${(dist / 0.75).toStringAsFixed(0)} خطوة'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _saveRoute(s),
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.bookmark_add),
                  label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ المسار'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, s),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('ابدأ الآن'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
