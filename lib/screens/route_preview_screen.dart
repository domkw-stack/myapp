import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/saved_route.dart';
import '../models/elevation_point.dart';
import '../services/location_service.dart';
import '../services/elevation_service.dart';

class RoutePreviewScreen extends StatefulWidget {
  final SavedRoute route;
  const RoutePreviewScreen({super.key, required this.route});

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late TabController _tabController;
  List<LatLng> _routePoints = [];
  ElevationProfile? _elevationProfile;
  bool _loadingElevation = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _tabController = TabController(length: 2, vsync: this);
    _routePoints = LocationService.decodeRoutePoints(widget.route.routePoints);
    _loadElevation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadElevation() async {
    if (_routePoints.length < 2) return;
    setState(() => _loadingElevation = true);
    try {
      final profile = await ElevationService.instance.buildProfile(_routePoints);
      setState(() => _elevationProfile = profile);
    } catch (_) {}
    setState(() => _loadingElevation = false);
  }

  LatLng get _center {
    if (_routePoints.isEmpty) return const LatLng(24.7136, 46.6753);
    double latSum = 0, lngSum = 0;
    for (final p in _routePoints) { latSum += p.latitude; lngSum += p.longitude; }
    return LatLng(latSum / _routePoints.length, lngSum / _routePoints.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.route.name),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'الخريطة'),
            Tab(icon: Icon(Icons.terrain), text: 'الارتفاع'),
          ],
        ),
      ),
      body: Column(
        children: [
          // بطاقة معلومات المسار
          _buildInfoCard(theme),
          // المحتوى
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMapView(theme),
                _buildElevationView(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _infoItem(Icons.straighten, widget.route.distanceFormatted, 'المسافة', theme),
            _infoItem(Icons.flag, widget.route.difficultyLabel, 'الصعوبة', theme),
            if (_elevationProfile != null) ...[
              _infoItem(Icons.arrow_upward, '${_elevationProfile!.totalGain.toStringAsFixed(0)} م', 'ارتفاع', theme),
              _infoItem(Icons.arrow_downward, '${_elevationProfile!.totalLoss.toStringAsFixed(0)} م', 'انخفاض', theme),
            ] else
              _infoItem(Icons.directions_walk,
                  '${(_routePoints.length)}', 'نقطة', theme),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String value, String label, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMapView(ThemeData theme) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.walktracker.app',
            ),
            if (_routePoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: theme.colorScheme.primary,
                    strokeWidth: 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            if (_routePoints.isNotEmpty)
              MarkerLayer(markers: [
                // نقطة البداية
                Marker(
                  point: _routePoints.first,
                  width: 44, height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 22),
                  ),
                ),
                // نقطة النهاية (إن كانت مختلفة)
                if (_routePoints.last != _routePoints.first)
                  Marker(
                    point: _routePoints.last,
                    width: 44, height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(Icons.sports_score, color: Colors.white, size: 22),
                    ),
                  ),
              ]),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton.small(
            onPressed: () => _mapController.move(_center, 15),
            child: const Icon(Icons.center_focus_strong),
          ),
        ),
      ],
    );
  }

  Widget _buildElevationView(ThemeData theme) {
    if (_loadingElevation) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جارٍ تحميل بيانات الارتفاع...'),
          ],
        ),
      );
    }

    if (_elevationProfile == null || _elevationProfile!.points.isEmpty) {
      return const Center(child: Text('لا تتوفر بيانات الارتفاع'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ملخص الارتفاع
          Row(
            children: [
              Expanded(child: _elevationStat(theme, '↑', '${_elevationProfile!.totalGain.toStringAsFixed(0)} م', 'إجمالي الصعود', Colors.orange)),
              Expanded(child: _elevationStat(theme, '↓', '${_elevationProfile!.totalLoss.toStringAsFixed(0)} م', 'إجمالي الهبوط', Colors.blue)),
              Expanded(child: _elevationStat(theme, '⛰', '${_elevationProfile!.maxElevation.toStringAsFixed(0)} م', 'أقصى ارتفاع', Colors.purple)),
            ],
          ),
          const SizedBox(height: 20),
          Text('مخطط الارتفاع', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          // رسم مخطط الارتفاع يدوياً بـ CustomPainter
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevationChartPainterWidget(profile: _elevationProfile!, theme: theme),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // تصنيف الصعوبة
          Card(
            color: _difficultyColor(_elevationProfile!.difficultyFromElevation).withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: _difficultyColor(_elevationProfile!.difficultyFromElevation)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مستوى الصعوبة بناءً على الارتفاع',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        Text(_difficultyText(_elevationProfile!.difficultyFromElevation),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _difficultyColor(_elevationProfile!.difficultyFromElevation),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _elevationStat(ThemeData theme, String emoji, String value, String label, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Color _difficultyColor(String d) {
    switch (d) {
      case 'easy': return Colors.green;
      case 'medium': return Colors.orange;
      case 'hard': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _difficultyText(String d) {
    switch (d) {
      case 'easy': return 'سهل — تضاريس مسطحة مناسبة للجميع';
      case 'medium': return 'متوسط — بعض المنحدرات تحتاج لجهد معتدل';
      case 'hard': return 'صعب — منحدرات حادة تتطلب لياقة جيدة';
      default: return '';
    }
  }
}

// ─── رسم مخطط الارتفاع ────────────────────────────────────────────────────────
class ElevationChartPainterWidget extends StatelessWidget {
  final ElevationProfile profile;
  final ThemeData theme;

  const ElevationChartPainterWidget({super.key, required this.profile, required this.theme});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      return CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _ElevationPainter(profile: profile, theme: theme),
      );
    });
  }
}

class _ElevationPainter extends CustomPainter {
  final ElevationProfile profile;
  final ThemeData theme;

  _ElevationPainter({required this.profile, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.points.isEmpty) return;

    const padding = EdgeInsets.fromLTRB(40, 10, 10, 30);
    final drawW = size.width - padding.left - padding.right;
    final drawH = size.height - padding.top - padding.bottom;

    final minEl = profile.minElevation - 5;
    final maxEl = profile.maxElevation + 5;
    final maxDist = profile.points.last.distanceFromStart;

    if (maxDist == 0 || maxEl == minEl) return;

    // دالة تحويل نقطة
    Offset toOffset(ElevationPoint p) {
      final x = padding.left + (p.distanceFromStart / maxDist) * drawW;
      final y = padding.top + drawH - ((p.elevation - minEl) / (maxEl - minEl)) * drawH;
      return Offset(x, y);
    }

    // رسم خطوط الشبكة
    final gridPaint = Paint()..color = Colors.grey.withOpacity(0.2)..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = padding.top + drawH * i / 4;
      canvas.drawLine(Offset(padding.left, y), Offset(padding.left + drawW, y), gridPaint);
      final el = maxEl - (maxEl - minEl) * i / 4;
      final tp = TextPainter(
        text: TextSpan(text: '${el.toStringAsFixed(0)}م', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - 6));
    }

    // مسار التعبئة
    final fillPath = ui.Path();
    final firstOffset = toOffset(profile.points.first);
    fillPath.moveTo(padding.left, padding.top + drawH);
    fillPath.lineTo(firstOffset.dx, firstOffset.dy);
    for (final p in profile.points) {
      fillPath.lineTo(toOffset(p).dx, toOffset(p).dy);
    }
    fillPath.lineTo(padding.left + drawW, padding.top + drawH);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          theme.colorScheme.primary.withOpacity(0.6),
          theme.colorScheme.primary.withOpacity(0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, padding.top, size.width, drawH));
    canvas.drawPath(fillPath, fillPaint);

    // خط المسار
    final linePaint = Paint()
      ..color = theme.colorScheme.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = ui.Path();
    linePath.moveTo(firstOffset.dx, firstOffset.dy);
    for (final p in profile.points) {
      linePath.lineTo(toOffset(p).dx, toOffset(p).dy);
    }
    canvas.drawPath(linePath, linePaint);

    // تسميات المسافة على المحور الأفقي
    for (int i = 0; i <= 4; i++) {
      final dist = maxDist * i / 4;
      final x = padding.left + drawW * i / 4;
      final label = dist >= 1000 ? '${(dist / 1000).toStringAsFixed(1)}كم' : '${dist.toStringAsFixed(0)}م';
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
