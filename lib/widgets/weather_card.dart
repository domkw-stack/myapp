import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';

class WeatherCard extends StatefulWidget {
  final bool compact;
  const WeatherCard({super.key, this.compact = false});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  WeatherData? _weather;
  List<HourlyForecast> _hourly = [];
  bool _loading = true;
  String _error = '';
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() { _loading = false; _error = 'يرجى منح إذن الموقع'; });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 8));

      final weather = await WeatherService.instance.getWeather(pos.latitude, pos.longitude);
      final hourly  = await WeatherService.instance.getHourly(pos.latitude, pos.longitude);

      if (mounted) setState(() {
        _weather = weather;
        _hourly  = hourly;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'تعذر جلب بيانات الطقس';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) return _loadingWidget(theme);
    if (_error.isNotEmpty || _weather == null) return _errorWidget(theme);

    final w = _weather!;
    final advice = w.walkAdvice;

    if (widget.compact) return _buildCompact(w, advice);
    return _buildFull(w, advice, theme);
  }

  // ─── النسخة الكاملة ──────────────────────────────────────────────────────
  Widget _buildFull(WeatherData w, WalkAdvice advice, ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: w.isDay
                ? [const Color(0xFF1976D2), const Color(0xFF42A5F5)]
                : [const Color(0xFF1A237E), const Color(0xFF3949AB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(
            color: (w.isDay ? Colors.blue : Colors.indigo).withOpacity(0.35),
            blurRadius: 18, offset: const Offset(0, 5),
          )],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ─ صف الطقس الرئيسي
            Row(children: [
              Text(w.emoji, style: const TextStyle(fontSize: 52)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${w.temperature.round()}°',
                    style: const TextStyle(color: Colors.white, fontSize: 44,
                        fontWeight: FontWeight.bold, height: 1.0)),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(' يشعر كـ${w.feelsLike.round()}°',
                      style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
                  ),
                ]),
                Text(w.description,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
              ])),
              // تفاصيل جانبية
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _detail('💧', '${w.humidity.round()}%'),
                const SizedBox(height: 5),
                _detail('💨', '${w.windSpeed.round()} كم/س'),
                const SizedBox(height: 5),
                _detail('🔆', 'UV ${w.uvIndex.round()}'),
              ]),
            ]),

            const SizedBox(height: 12),

            // ─ نصيحة المشي
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: advice.color.withOpacity(0.28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: advice.color.withOpacity(0.55)),
              ),
              child: Row(children: [
                Text(advice.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(advice.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(advice.message,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                ])),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white70),
              ]),
            ),

            // ─ توقعات ساعة بساعة (قابل للطي)
            if (_expanded) ...[
              const SizedBox(height: 14),
              Text('التوقعات خلال اليوم',
                style: TextStyle(color: Colors.white.withOpacity(0.75),
                    fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_hourly.isEmpty)
                const Center(child: Text('جارٍ التحميل...', style: TextStyle(color: Colors.white60, fontSize: 12)))
              else
                SizedBox(
                  height: 82,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _hourly.length,
                    itemBuilder: (_, i) => _hourlyItem(_hourly[i]),
                  ),
                ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _load,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.refresh, color: Colors.white.withOpacity(0.55), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'تحديث — آخر تحديث ${_fmt(w.fetchTime)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ─── النسخة المدمجة (للشاشة الرئيسية أثناء المشي) ─────────────────────
  Widget _buildCompact(WeatherData w, WalkAdvice advice) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [advice.color.withOpacity(0.85), advice.color.withOpacity(0.6)],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ),
      ),
      child: Row(children: [
        Text(w.emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 8),
        Text('${w.temperature.round()}°',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(width: 8),
        Expanded(child: Text(advice.title,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text(advice.emoji, style: const TextStyle(fontSize: 18)),
      ]),
    );
  }

  Widget _detail(String icon, String val) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(icon, style: const TextStyle(fontSize: 12)),
    const SizedBox(width: 3),
    Text(val, style: const TextStyle(color: Colors.white, fontSize: 12)),
  ]);

  Widget _hourlyItem(HourlyForecast h) => Container(
    width: 58, margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      Text('${h.time.hour.toString().padLeft(2,'0')}:00',
        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
      Text(h.emoji, style: const TextStyle(fontSize: 18)),
      Text('${h.temperature.round()}°',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      if (h.precipitation > 20)
        Text('${h.precipitation.round()}%',
          style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 9)),
    ]),
  );

  Widget _loadingWidget(ThemeData theme) => Container(
    height: 110, margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF42A5F5)]),
    ),
    child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      SizedBox(height: 8),
      Text('جارٍ تحميل الطقس...', style: TextStyle(color: Colors.white, fontSize: 13)),
    ])),
  );

  Widget _errorWidget(ThemeData theme) => GestureDetector(
    onTap: _load,
    child: Container(
      height: 52, margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surfaceVariant,
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off, color: Colors.grey),
        const SizedBox(width: 8),
        Text(_error, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(width: 8),
        const Icon(Icons.refresh, color: Colors.grey, size: 18),
      ]),
    ),
  );

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
}
