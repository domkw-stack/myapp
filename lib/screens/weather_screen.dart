import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/weather_card.dart';
import '../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  List<DailyForecast> _daily = [];
  bool _loadingDaily = false;

  @override
  void initState() {
    super.initState();
    _loadDaily();
  }

  Future<void> _loadDaily() async {
    setState(() => _loadingDaily = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) { setState(() => _loadingDaily = false); return; }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium)
          .timeout(const Duration(seconds: 8));
      final daily = await WeatherService.instance.getDaily(pos.latitude, pos.longitude);
      if (mounted) setState(() { _daily = daily; _loadingDaily = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDaily = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('حالة الطقس 🌤️'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            setState(() {});
            _loadDaily();
          }),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // البطاقة الرئيسية مع التوقعات بالساعة
          const WeatherCard(),
          const SizedBox(height: 8),

          // ─ توقعات 7 أيام
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text('توقعات الأسبوع',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (_loadingDaily)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ))
          else if (_daily.isNotEmpty)
            _buildWeekForecast(theme)
          else
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('تعذر جلب التوقعات', style: TextStyle(color: Colors.grey.shade500)),
            ),

          const SizedBox(height: 12),

          // ─ نصائح المشي حسب الطقس
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('نصائح المشي حسب الطقس',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          _buildTips(theme),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildWeekForecast(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
      ),
      child: Column(
        children: List.generate(_daily.length, (i) {
          final d = _daily[i];
          final isToday = i == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: i < _daily.length - 1
                  ? Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.3)))
                  : null,
            ),
            child: Row(children: [
              SizedBox(
                width: 68,
                child: Text(
                  isToday ? 'اليوم' : _dayName(d.date),
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
              Text(d.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Text(d.description,
                style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Row(children: [
                Text('${d.tempMax.round()}°',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 4),
                Text('${d.tempMin.round()}°',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ]),
            ]),
          );
        }),
      ),
    );
  }

  String _dayName(DateTime d) {
    const names = ['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    return names[d.weekday - 1];
  }

  Widget _buildTips(ThemeData theme) {
    final tips = [
      ('☀️ حار (32°+)',    'امشِ قبل 8 صباحاً أو بعد 6 مساءً، اشرب 500مل ماء قبل البدء',   Colors.deepOrange),
      ('🌤️ معتدل (20-28°)', 'وقت مثالي! اشرب ماءً كل 20 دقيقة للحفاظ على الطاقة',          Colors.green),
      ('🧥 بارد (5-15°)',   'سخّن عضلاتك 5 دقائق، ارتدِ طبقتين وقفازات',                    Colors.indigo),
      ('🌧️ ممطر',          'استخدم حذاء بنعل مطاطي، تجنب المسالك الترابية',                  Colors.blueGrey),
      ('💨 رياح (+40 كم/س)','تجنب المناطق المكشوفة والأشجار الكبيرة',                         Colors.purple),
      ('🌫️ ضباب',          'قلّل السرعة، ابقَ في الأماكن المعروفة لديك',                      Colors.grey),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: tips.map((t) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: t.$3.withOpacity(0.07),
          border: Border.all(color: t.$3.withOpacity(0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 4, height: 36,
            decoration: BoxDecoration(color: t.$3, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.$1, style: TextStyle(fontWeight: FontWeight.bold, color: t.$3, fontSize: 13)),
            const SizedBox(height: 2),
            Text(t.$2, style: const TextStyle(fontSize: 12)),
          ])),
        ]),
      )).toList()),
    );
  }
}
