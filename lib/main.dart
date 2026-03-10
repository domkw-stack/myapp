import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/walk_screen.dart';
import 'screens/radio_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/badges_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    statusBarIconBrightness:  Brightness.light,
  ));
  runApp(const WalkTrackerApp());
}

class WalkTrackerApp extends StatelessWidget {
  const WalkTrackerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تتبع المشي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor:  const Color(0xFF00E676),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

// ─── الغلاف الرئيسي مع Drawer ─────────────────────────────────────────────
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _idx = 0;

  final _labels = ['المشي', 'راديو', 'الطقس', 'الشارات', 'السجل'];
  final _icons  = [
    Icons.map_rounded,
    Icons.radio_rounded,
    Icons.wb_sunny_rounded,
    Icons.emoji_events_rounded,
    Icons.history_rounded,
  ];
  final _screens = const [
    WalkScreen(),
    RadioScreen(),
    WeatherScreen(),
    BadgesScreen(),
    HistoryScreen(),
  ];

  void _goTo(int i) {
    setState(() => _idx = i);
    Navigator.pop(context); // أغلق الـ Drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      // ─── Drawer (القائمة الجانبية) ───────────────────────────────────────
      drawer: _buildDrawer(),
      // ─── الجسم ───────────────────────────────────────────────────────────
      body: Builder(builder: (ctx) => Stack(children: [
        // الشاشة الحالية
        IndexedStack(index: _idx, children: _screens),

        // زر القائمة فوق الخريطة (للشاشة الأولى فقط)
        if (_idx == 0)
          Positioned(
            top:  MediaQuery.of(ctx).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.45),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Icon(Icons.menu, color: Colors.white, size: 22),
              ),
            ),
          ),
      ])),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      width: 270,
      backgroundColor: const Color(0xFF0D0D1A),
      child: Column(children: [

        // ─ رأس القائمة
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 20, 20, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF1DE9B6)],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.2),
              ),
              child: const Icon(Icons.directions_walk, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 12),
            const Text('تتبع المشي',
              style: TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.bold)),
            const Text('المشي أسلوب حياة',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),

        const SizedBox(height: 8),

        // ─ العناصر
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _labels.length,
            itemBuilder: (_, i) {
              final isSelected = _idx == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? const Color(0xFF00E676).withOpacity(0.15)
                      : Colors.transparent,
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  leading: Icon(
                    _icons[i],
                    color: isSelected
                        ? const Color(0xFF00E676)
                        : Colors.white54,
                    size: 24,
                  ),
                  title: Text(
                    _labels[i],
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF00E676) : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  trailing: isSelected
                      ? Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00E676),
                          ),
                        )
                      : null,
                  onTap: () => _goTo(i),
                ),
              );
            },
          ),
        ),

        // ─ أسفل القائمة
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
          child: Column(children: [
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.info_outline, color: Colors.white24, size: 16),
              const SizedBox(width: 8),
              Text('الإصدار 6.0',
                style: TextStyle(color: Colors.white.withOpacity(0.25),
                    fontSize: 12)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
