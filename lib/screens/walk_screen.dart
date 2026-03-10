import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../services/weather_service.dart';
import '../services/radio_service.dart';
import '../services/database_service.dart';
import '../services/badge_service.dart';
import '../models/walk_session.dart';
import '../models/radio_station.dart';
import '../widgets/badge_popup.dart';
import 'radio_screen.dart';

class WalkScreen extends StatefulWidget {
  const WalkScreen({super.key});
  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen>
    with TickerProviderStateMixin {

  // ─── حالة المشي ──────────────────────────────────────────────────────────
  bool _isWalking = false;
  bool _isPaused  = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  Position? _currentPos;
  final _mapCtrl = MapController();

  // ─── إحصائيات ─────────────────────────────────────────────────────────────
  double _distance = 0;   // متر
  int    _steps    = 0;
  double _calories = 0;
  double _speed    = 0;   // كم/س

  // ─── المسارات ─────────────────────────────────────────────────────────────
  List<LatLng> _walkedPoints   = [];  // المسار المقطوع فعلياً
  List<LatLng> _plannedRoute   = [];  // المسار المخطط على الشوارع
  bool _loadingRoute = false;

  // ─── الطقس ────────────────────────────────────────────────────────────────
  WeatherData? _weather;

  // ─── الراديو ──────────────────────────────────────────────────────────────
  final _radio = RadioService.instance;
  RadioState _radioState = RadioState.stopped;
  RadioStation? _radioStation;

  // ─── الـ Bottom Sheet ─────────────────────────────────────────────────────
  final _sheetCtrl = DraggableScrollableController();

  // ─── الأنيميشن ────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>    _pulseAnim;

  // ─── ثوابت ───────────────────────────────────────────────────────────────
  static const _defaultPos = LatLng(33.5138, 36.2765); // دمشق
  static const _mapStyle = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _radio.onStateChanged   = (s) { if (mounted) setState(() => _radioState = s); };
    _radio.onStationChanged = (s) { if (mounted) setState(() => _radioStation = s); };
    _radio.init();

    _initLocation();
  }

  Future<void> _initLocation() async {
    final granted = await LocationService.instance.requestPermission();
    if (!granted) return;
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _currentPos = pos);
      _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 16);
      _loadWeather(pos);
    }
  }

  Future<void> _loadWeather(Position pos) async {
    final w = await WeatherService.instance.getWeather(pos.latitude, pos.longitude);
    if (mounted) setState(() => _weather = w);
  }

  // ─── بدء المشي ───────────────────────────────────────────────────────────
  Future<void> _startWalking() async {
    final granted = await LocationService.instance.requestPermission();
    if (!granted) return;

    setState(() {
      _isWalking  = true;
      _isPaused   = false;
      _elapsed    = Duration.zero;
      _distance   = 0;
      _steps      = 0;
      _calories   = 0;
      _walkedPoints = [];
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) setState(() => _elapsed += const Duration(seconds: 1));
    });

    LocationService.instance.startTracking((pos) {
      if (!mounted || _isPaused) return;
      setState(() {
        _currentPos = pos;
        _distance   = LocationService.instance.totalDistance;
        _steps      = LocationService.instance.stepCount;
        _calories   = LocationService.instance.calories;
        _speed      = LocationService.instance.calculateSpeed(pos);

        final pt = LatLng(pos.latitude, pos.longitude);
        _walkedPoints = List.from(LocationService.instance.routePoints);

        // تحريك الخريطة لتتبع المستخدم
        _mapCtrl.move(pt, _mapCtrl.camera.zoom);
      });
    });
  }

  void _pauseWalking() => setState(() => _isPaused = !_isPaused);

  Future<void> _stopWalking() async {
    _timer?.cancel();
    LocationService.instance.stopTracking();

    // حفظ الجلسة
    if (_distance > 10) {
      final session = WalkSession(
        date:          DateTime.now(),
        duration:      _elapsed.inSeconds,
        distance:      _distance,
        steps:         _steps,
        calories:      _calories.round(),
        avgSpeed:      LocationService.instance.calculateAvgSpeed(),
        routePoints:   LocationService.instance.encodeRoutePoints(),
        targetDistance: 0,
        tripType:      'free',
      );
      final db    = DatabaseService.instance;
      final id    = await db.insertWalkSession(session);
      final stats = await db.getStats();
      final badges = await BadgeService.instance.evaluateSession(
        session.copyWith(id: id),
        totalSessions:         stats['totalSessions'] as int,
        totalDistanceAllTime:  (stats['totalDistance'] as double),
      );

      if (mounted && badges.isNotEmpty) {
        BadgePopupHelper.show(context, badges.first);
      }
    }

    if (mounted) setState(() {
      _isWalking    = false;
      _isPaused     = false;
      _walkedPoints = [];
      _plannedRoute = [];
    });
  }

  // ─── تخطيط مسار على الشوارع ──────────────────────────────────────────────
  Future<void> _planRoute(double targetKm) async {
    if (_currentPos == null) return;
    setState(() => _loadingRoute = true);

    final center = LatLng(_currentPos!.latitude, _currentPos!.longitude);
    final route = await RoutingService.instance
        .getCircularRoute(center, targetKm * 1000);

    if (mounted) setState(() {
      _plannedRoute  = route;
      _loadingRoute  = false;
    });
  }

  // ─── واجهة المشغل ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [

        // ══════ الخريطة الكاملة ══════════════════════════════════════════════
        _buildMap(),

        // ══════ Overlay علوي: الوقت + الطقس ══════════════════════════════════
        _buildTopOverlay(),

        // ══════ إحصائيات مباشرة على الخريطة (أثناء المشي) ══════════════════
        if (_isWalking) _buildLiveStatsOverlay(),

        // ══════ زر البدء / الإيقاف (مركزي في الأسفل) ═══════════════════════
        if (!_isWalking) _buildStartButton(),

        // ══════ Bottom Sheet أثناء المشي ══════════════════════════════════════
        if (_isWalking) _buildBottomSheet(),

      ]),
    );
  }

  // ─── إحصائيات مباشرة على الخريطة ─────────────────────────────────────────
  Widget _buildLiveStatsOverlay() {
    return Positioned(
      bottom: 220,   // فوق الـ bottom sheet
      left: 12,
      right: 12,
      child: Row(children: [
        _liveStatBubble(
          '${(_distance / 1000).toStringAsFixed(2)}',
          'كم',
          Icons.straighten,
          const Color(0xFF00E676),
        ),
        const SizedBox(width: 8),
        _liveStatBubble(
          _formatDuration(_elapsed),
          '',
          Icons.timer,
          const Color(0xFF40C4FF),
          wide: true,
        ),
        const SizedBox(width: 8),
        _liveStatBubble(
          '${_speed.toStringAsFixed(1)}',
          'كم/س',
          Icons.speed,
          const Color(0xFFFFD740),
        ),
        const SizedBox(width: 8),
        _liveStatBubble(
          '$_steps',
          'خطوة',
          Icons.directions_walk,
          const Color(0xFFFF6E40),
        ),
      ]),
    );
  }

  Widget _liveStatBubble(String val, String unit, IconData icon, Color color,
      {bool wide = false}) {
    return Expanded(
      flex: wide ? 2 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 2),
            Text(
              unit.isEmpty ? val : '$val $unit',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: wide ? 13 : 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
      ),
    );
  }

  // ─── الخريطة ─────────────────────────────────────────────────────────────
  Widget _buildMap() {
    final center = _currentPos != null
        ? LatLng(_currentPos!.latitude, _currentPos!.longitude)
        : _defaultPos;

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // طبقة الخريطة
        TileLayer(
          urlTemplate: _mapStyle,
          userAgentPackageName: 'com.example.myapp',
          retinaMode: MediaQuery.of(context).devicePixelRatio > 1.5,
        ),

        // المسار المخطط (رمادي فاتح)
        if (_plannedRoute.length > 1)
          PolylineLayer(polylines: [
            Polyline(
              points:       _plannedRoute,
              color:        Colors.white.withOpacity(0.6),
              strokeWidth:  4,
            ),
          ]),

        // المسار المقطوع (أخضر متدرج)
        if (_walkedPoints.length > 1)
          PolylineLayer(polylines: [
            Polyline(
              points:      _walkedPoints,
              color:       const Color(0xFF00E676),
              strokeWidth: 5,
              borderColor: Colors.black.withOpacity(0.2),
              borderStrokeWidth: 1,
            ),
          ]),

        // موقع المستخدم
        if (_currentPos != null)
          MarkerLayer(markers: [
            Marker(
              point:  LatLng(_currentPos!.latitude, _currentPos!.longitude),
              width:  48,
              height: 48,
              child:  _buildLocationMarker(),
            ),
          ]),
      ],
    );
  }

  Widget _buildLocationMarker() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Stack(alignment: Alignment.center, children: [
        // دائرة نبضية خارجية
        if (_isWalking)
          Container(
            width:  48 * _pulseAnim.value,
            height: 48 * _pulseAnim.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E676).withOpacity(0.2),
            ),
          ),
        // النقطة الرئيسية
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isWalking ? const Color(0xFF00E676) : Colors.blue,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(
              color: (_isWalking ? const Color(0xFF00E676) : Colors.blue)
                  .withOpacity(0.5),
              blurRadius: 8,
            )],
          ),
        ),
      ]),
    );
  }

  // ─── Overlay علوي ────────────────────────────────────────────────────────
  Widget _buildTopOverlay() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.65), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
            64, // مسافة لزر القائمة في AppShell
            MediaQuery.of(context).padding.top + 8,
            12, 24),
        child: Row(children: [

          // الطقس
          if (_weather != null) ...[
            Text(_weather!.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 5),
            Text('${_weather!.temperature.round()}°',
              style: const TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _weather!.walkAdvice.color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _weather!.walkAdvice.color.withOpacity(0.5)),
              ),
              child: Text(_weather!.walkAdvice.emoji,
                style: const TextStyle(fontSize: 12)),
            ),
          ],

          const Spacer(),

          // أزرار التحكم بالخريطة (عمودياً على اليمين)
          Column(mainAxisSize: MainAxisSize.min, children: [
            if (!_isWalking)
              _mapBtn(Icons.route, _showRoutePlanDialog,
                  tooltip: 'خطط مساراً'),
            if (!_isWalking) const SizedBox(height: 6),
            _mapBtn(Icons.add, () =>
                _mapCtrl.move(_mapCtrl.camera.center,
                    (_mapCtrl.camera.zoom + 1).clamp(3.0, 19.0))),
            const SizedBox(height: 6),
            _mapBtn(Icons.remove, () =>
                _mapCtrl.move(_mapCtrl.camera.center,
                    (_mapCtrl.camera.zoom - 1).clamp(3.0, 19.0))),
            const SizedBox(height: 6),
            _mapBtn(Icons.my_location, () {
              if (_currentPos != null) {
                _mapCtrl.move(
                    LatLng(_currentPos!.latitude, _currentPos!.longitude), 16);
              }
            }),
          ]),
        ]),
      ),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap, {String? tooltip}) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.45),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  // ─── زر البدء ─────────────────────────────────────────────────────────────
  Widget _buildStartButton() {
    return Positioned(
      bottom: 40, left: 0, right: 0,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // بطاقة الراديو صغيرة (إذا يعمل)
          if (_radioStation != null && _radioState == RadioState.playing)
            _buildMiniRadioChip(),

          const SizedBox(height: 16),

          // زر البدء الكبير
          GestureDetector(
            onTap: _startWalking,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF1DE9B6)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF00E676).withOpacity(0.5),
                  blurRadius: 20, spreadRadius: 2,
                )],
              ),
              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.directions_walk, color: Colors.white, size: 32),
                Text('ابدأ', style: TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),

          const SizedBox(height: 12),
          Text(
            _plannedRoute.isNotEmpty
                ? '${(RoutingService.instance.routeDistanceMeters(_plannedRoute) / 1000).toStringAsFixed(1)} كم مخطط'
                : 'اضغط للبدء',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
          ),
        ]),
      ),
    );
  }

  // ─── Bottom Sheet أثناء المشي ─────────────────────────────────────────────
  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      controller:       _sheetCtrl,
      initialChildSize: 0.22,
      minChildSize:     0.14,
      maxChildSize:     0.65,
      snap:             true,
      snapSizes:        const [0.14, 0.22, 0.65],
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color:        Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller:  scrollCtrl,
          padding:     EdgeInsets.zero,
          physics:     const ClampingScrollPhysics(),
          children: [

            // مقبض السحب
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ══ الإحصائيات الرئيسية ══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _statCard('${(_distance / 1000).toStringAsFixed(2)}', 'كم', Icons.straighten, const Color(0xFF00E676)),
                const SizedBox(width: 10),
                _statCard('$_steps', 'خطوة', Icons.directions_walk, const Color(0xFF40C4FF)),
                const SizedBox(width: 10),
                _statCard('${_calories.toStringAsFixed(0)}', 'سعرة', Icons.local_fire_department, const Color(0xFFFF6E40)),
                const SizedBox(width: 10),
                _statCard('${_speed.toStringAsFixed(1)}', 'كم/س', Icons.speed, const Color(0xFFE040FB)),
              ]),
            ),

            const SizedBox(height: 12),

            // ══ شريط التحكم ══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [

                // إيقاف مؤقت
                _ctrlBtn(
                  _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  _isPaused ? 'استمرار' : 'إيقاف',
                  const Color(0xFF40C4FF),
                  _pauseWalking,
                ),

                // إنهاء
                _ctrlBtn(Icons.stop_rounded, 'إنهاء',
                    const Color(0xFFFF5252), _confirmStop),

                // تخطيط مسار
                _ctrlBtn(Icons.route, 'مسار',
                    const Color(0xFFFFD740), () => _showRoutePlanDialog()),

                // راديو
                _ctrlBtn(
                  _radioState == RadioState.playing
                      ? Icons.pause_circle : Icons.radio,
                  'راديو',
                  const Color(0xFFE040FB),
                  () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RadioScreen())),
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // ══ الراديو المدمج ══
            if (_radioStation != null || _radioState != RadioState.stopped)
              _buildRadioPanel(),

            // ══ الطقس المدمج ══
            if (_weather != null)
              _buildWeatherPanel(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _ctrlBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(color: color.withOpacity(0.5), width: 2),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
      ]),
    );
  }

  Widget _buildRadioPanel() {
    final color = const Color(0xFFE040FB);
    final isPlaying = _radioState == RadioState.playing;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Text(_radioStation?.flag ?? '📻', style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Text(_radioStation?.name ?? 'راديو',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(isPlaying ? '● يبث الآن' : 'متوقف',
            style: TextStyle(
              color: isPlaying ? const Color(0xFF00E676) : Colors.white54,
              fontSize: 11)),
        ])),
        IconButton(
          icon: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: color, size: 28),
          onPressed: () {
            if (isPlaying) _radio.stop();
            else if (_radioStation != null) _radio.play(_radioStation!);
          },
        ),
        IconButton(
          icon: const Icon(Icons.open_in_new, color: Colors.white54, size: 18),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const RadioScreen())),
        ),
      ]),
    );
  }

  Widget _buildWeatherPanel() {
    final w = _weather!;
    final advice = w.walkAdvice;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(children: [
        Text(w.emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text('${w.temperature.round()}°',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(width: 8),
            Text(w.description,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
          Text('${advice.emoji} ${advice.title}',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
        ])),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
            children: [
          Text('💧 ${w.humidity.round()}%',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
          Text('💨 ${w.windSpeed.round()} كم/س',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _buildMiniRadioChip() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RadioScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE040FB).withOpacity(0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.graphic_eq, color: Color(0xFFE040FB), size: 16),
          const SizedBox(width: 6),
          Text(_radioStation!.name,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      ),
    );
  }

  // ─── حوار تخطيط المسار ───────────────────────────────────────────────────
  void _showRoutePlanDialog() {
    double km = 3.0;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('تخطيط مسار على الشوارع',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('يتبع الطرق الفعلية ولا يمر عبر المباني',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 20),
            Text('${km.toStringAsFixed(1)} كم',
              style: const TextStyle(color: Color(0xFF00E676), fontSize: 36,
                  fontWeight: FontWeight.bold)),
            Slider(
              value: km, min: 1, max: 10,
              divisions: 18,
              activeColor: const Color(0xFF00E676),
              inactiveColor: Colors.white12,
              onChanged: (v) => setLocal(() => km = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['1 كم', '3 كم', '5 كم', '10 كم'].map((t) =>
                Text(t, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ).toList(),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                ),
                child: const Text('إلغاء'),
              )),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(
                onPressed: _loadingRoute ? null : () {
                  Navigator.pop(ctx);
                  _planRoute(km);
                },
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676)),
                child: _loadingRoute
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: Colors.black))
                    : const Text('رسم المسار', style: TextStyle(color: Colors.black)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  void _confirmStop() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('إنهاء المشي؟', style: TextStyle(color: Colors.white)),
        content: Text(
          'قطعت ${(_distance / 1000).toStringAsFixed(2)} كم\n$_steps خطوة',
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تراجع', style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () { Navigator.pop(context); _stopWalking(); },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            child: const Text('إنهاء', style: TextStyle(color: Colors.black))),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }
}