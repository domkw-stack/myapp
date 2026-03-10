import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../services/badge_service.dart';
import '../models/walk_session.dart';
import '../models/saved_route.dart';
import '../models/badge.dart';
import '../widgets/badge_popup.dart';
import '../widgets/mini_radio_player.dart';
import '../widgets/weather_card.dart';
import 'map_screen.dart';
import 'walk_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isWalking = false;
  bool _isPaused = false;
  double _targetDistance = 2000;
  String _tripType = 'one_way';
  
  double _currentDistance = 0;
  double _previousDistance = 0; // لرصد معالم الشارات
  int _stepCount = 0;
  double _calories = 0;
  double _currentSpeed = 0;
  Duration _elapsed = Duration.zero;
  Position? _currentPosition;
  
  Timer? _timer;
  DateTime? _startTime;
  DateTime? _pauseTime;
  Duration _pausedDuration = Duration.zero;
  int? _currentSessionId;
  List<WalkBadge> _postSessionBadges = [];

  @override
  void dispose() {
    _timer?.cancel();
    LocationService.instance.stopTracking();
    super.dispose();
  }

  Future<void> _startWalk() async {
    final setup = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const WalkSetupScreen()),
    );
    
    if (setup == null) return;

    final hasPermission = await LocationService.instance.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى منح صلاحية الموقع للتطبيق')),
        );
      }
      return;
    }

    setState(() {
      _targetDistance = setup['distance'];
      _tripType = setup['tripType'];
      _isWalking = true;
      _isPaused = false;
      _currentDistance = 0;
      _stepCount = 0;
      _calories = 0;
      _elapsed = Duration.zero;
      _pausedDuration = Duration.zero;
    });

    _startTime = DateTime.now();
    
    // حفظ الجلسة في قاعدة البيانات
    final session = WalkSession(
      date:           _startTime!,
      duration:       0,
      distance:       0,
      targetDistance: _tripType == 'round_trip' ? _targetDistance * 2 : _targetDistance,
      tripType:       _tripType,
      steps:          0,
      calories:       0,
      routePoints:    '[]',
      avgSpeed:       0,
    );
    _currentSessionId = await DatabaseService.instance.insertWalkSession(session);

    // بدء تتبع الموقع
    LocationService.instance.startTracking((position) {
      if (mounted && _isWalking && !_isPaused) {
        final newDistance = LocationService.instance.totalDistance;
        
        // ─ فحص شارات المسافة اللحظية ─
        final milestone = BadgeService.instance.checkLiveMilestone(_previousDistance, newDistance);
        if (milestone != null) {
          BadgePopupHelper.show(context, milestone);
        }

        setState(() {
          _previousDistance = _currentDistance;
          _currentPosition = position;
          _currentDistance = newDistance;
          _stepCount = LocationService.instance.stepCount;
          _calories = LocationService.instance.calories;
          _currentSpeed = LocationService.instance.calculateSpeed(position);
        });
        
        // تحقق من الوصول للهدف
        final actualTarget = _tripType == 'round_trip' ? _targetDistance * 2 : _targetDistance;
        if (_currentDistance >= actualTarget) {
          _completeWalk();
        }
      }
    });

    // مؤقت للوقت
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isWalking && !_isPaused) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!) - _pausedDuration;
        });
      }
    });
  }

  void _pauseWalk() {
    setState(() => _isPaused = true);
    _pauseTime = DateTime.now();
    LocationService.instance.stopTracking();
  }

  void _resumeWalk() {
    if (_pauseTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseTime!);
    }
    setState(() => _isPaused = false);
    LocationService.instance.startTracking((position) {
      if (mounted && _isWalking && !_isPaused) {
        setState(() {
          _currentPosition = position;
          _currentDistance = LocationService.instance.totalDistance;
          _stepCount = LocationService.instance.stepCount;
          _calories = LocationService.instance.calories;
          _currentSpeed = LocationService.instance.calculateSpeed(position);
        });
      }
    });
  }

  Future<void> _stopWalk() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إيقاف المشي'),
        content: const Text('هل تريد إيقاف الجلسة الحالية؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('نعم')),
        ],
      ),
    );
    if (confirm == true) _completeWalk(forced: true);
  }

  Future<void> _completeWalk({bool forced = false}) async {
    _timer?.cancel();
    LocationService.instance.stopTracking();
    
    if (_currentSessionId != null) {
      final now = DateTime.now();
      final session = WalkSession(
        id:             _currentSessionId,
        date:           _startTime!,
        duration:       _startTime != null ? now.difference(_startTime!).inSeconds : 0,
        distance:       _currentDistance,
        targetDistance: _tripType == 'round_trip' ? _targetDistance * 2 : _targetDistance,
        tripType:       _tripType,
        steps:          _stepCount,
        calories:       _calories.round(),
        routePoints:    LocationService.instance.encodeRoutePoints(),
        avgSpeed:       LocationService.instance.calculateAvgSpeed(),
      );
      await DatabaseService.instance.insertWalkSession(session);

      // ─ تقييم شارات نهاية الجلسة ─
      if (!forced) {
        final stats = await DatabaseService.instance.getStats();
        final newBadges = await BadgeService.instance.evaluateSession(
          session,
          totalSessions: stats['totalSessions'] as int,
          totalDistanceAllTime: stats['totalDistance'] as double,
        );
        // عرض شارات ما بعد الجلسة (غير اللحظية) في نافذة الإنجاز
        if (mounted && newBadges.isNotEmpty) {
          _postSessionBadges = newBadges.where((b) =>
            b.category != BadgeCategory.distance || b.id.startsWith('td_')
          ).toList();
        }
      }
    }

    setState(() {
      _isWalking = false;
      _isPaused = false;
    });

    if (mounted && !forced) {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 32),
            SizedBox(width: 8),
            Text('أحسنت! 🎉'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('لقد أتممت جلسة المشي بنجاح!'),
              const SizedBox(height: 16),
              _statRow(Icons.straighten, 'المسافة', '${(_currentDistance / 1000).toStringAsFixed(2)} كم'),
              _statRow(Icons.timer, 'الوقت', _formatDuration(_elapsed)),
              _statRow(Icons.directions_walk, 'الخطوات', '$_stepCount'),
              _statRow(Icons.local_fire_department, 'السعرات', '${_calories.toStringAsFixed(0)} سعرة'),
              // ─ شارات جديدة ─
              if (_postSessionBadges.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Text('شارات جديدة مكتسبة!',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                ]),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _postSessionBadges.map((b) => Tooltip(
                    message: b.title,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [b.color, b.color.withOpacity(0.5)]),
                        boxShadow: [BoxShadow(color: b.color.withOpacity(0.4), blurRadius: 8)],
                      ),
                      child: Text(b.emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showSaveRouteDialog();
            },
            icon: const Icon(Icons.bookmark_add),
            label: const Text('حفظ المسار'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('رائع!'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSaveRouteDialog() async {
    final nameController = TextEditingController(
        text: 'مساري - ${DateTime.now().day}/${DateTime.now().month}');
    final descController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bookmark_add, color: Colors.teal),
            SizedBox(width: 8),
            Text('حفظ المسار'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المسار',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'وصف (اختياري)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );

    if (confirmed == true && nameController.text.isNotEmpty) {
      final route = SavedRoute(
        name: nameController.text,
        description: descController.text.isEmpty
            ? '${(_currentDistance / 1000).toStringAsFixed(2)} كم - ${_formatDuration(_elapsed)}'
            : descController.text,
        routePoints: LocationService.instance.encodeRoutePoints(),
        distanceMeters: _currentDistance,
        difficulty: _currentDistance < 2000 ? 'easy' : _currentDistance < 5000 ? 'medium' : 'hard',
        createdAt: DateTime.now(),
        thumbnailColor: 'teal',
      );
      await DatabaseService.instance.insertSavedRoute(route);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check, color: Colors.white),
              SizedBox(width: 8),
              Text('تم حفظ المسار في مساراتك المفضلة!'),
            ]),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}س ${m}د ${s}ث';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progressValue {
    final target = _tripType == 'round_trip' ? _targetDistance * 2 : _targetDistance;
    if (target <= 0) return 0;
    return (_currentDistance / target).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع المشي'),
        centerTitle: true,
        actions: [
          if (_isWalking)
            IconButton(
              icon: const Icon(Icons.map),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapScreen(
                      routePoints: LocationService.instance.routePoints,
                      currentPosition: _currentPosition,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isWalking) ...[
              const WeatherCard(),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildStartCard(theme),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildWalkingCard(theme),
              ),
              const SizedBox(height: 10),
              const WeatherCard(compact: true),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildStatsGrid(theme),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildProgressCard(theme),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const MiniRadioPlayer(),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildControlButtons(theme),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStartCard(ThemeData theme) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.directions_walk, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'ابدأ رحلتك',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تتبع مسافتك، خطواتك، وسعراتك الحرارية',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _startWalk,
              icon: const Icon(Icons.play_arrow, size: 28),
              label: const Text('ابدأ المشي', style: TextStyle(fontSize: 18)),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkingCard(ThemeData theme) {
    return Card(
      elevation: 4,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPaused ? '⏸ متوقف مؤقتاً' : '🏃 جارٍ المشي...',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  _tripType == 'round_trip' ? 'ذهاب وإياب' : 'ذهاب فقط',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            Text(
              _formatDuration(_elapsed),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _statCard(theme, Icons.straighten, 
          _currentDistance >= 1000
            ? '${(_currentDistance / 1000).toStringAsFixed(2)} كم'
            : '${_currentDistance.toStringAsFixed(0)} م',
          'المسافة', Colors.blue),
        _statCard(theme, Icons.directions_walk, '$_stepCount', 'الخطوات', Colors.orange),
        _statCard(theme, Icons.local_fire_department, '${_calories.toStringAsFixed(0)}', 'السعرات', Colors.red),
        _statCard(theme, Icons.speed, '${_currentSpeed.toStringAsFixed(1)} كم/س', 'السرعة', Colors.purple),
      ],
    );
  }

  Widget _statCard(ThemeData theme, IconData icon, String value, String label, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(ThemeData theme) {
    final target = _tripType == 'round_trip' ? _targetDistance * 2 : _targetDistance;
    final remaining = (target - _currentDistance).clamp(0.0, double.infinity);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('التقدم', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text('${(_progressValue * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progressValue,
                minHeight: 16,
                backgroundColor: theme.colorScheme.surfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المتبقي: ${remaining >= 1000 ? '${(remaining/1000).toStringAsFixed(2)} كم' : '${remaining.toStringAsFixed(0)} م'}',
                  style: theme.textTheme.bodySmall),
                Text('الهدف: ${target >= 1000 ? '${(target/1000).toStringAsFixed(1)} كم' : '${target.toStringAsFixed(0)} م'}',
                  style: theme.textTheme.bodySmall),
              ],
            ),
            if (_tripType == 'round_trip' && _currentDistance >= _targetDistance) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.turn_right, color: Colors.amber),
                    const SizedBox(width: 8),
                    const Text('حان وقت العودة! استدر الآن 🔄',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _stopWalk,
            icon: const Icon(Icons.stop, color: Colors.red),
            label: const Text('إيقاف', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 52),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _isPaused ? _resumeWalk : _pauseWalk,
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            label: Text(_isPaused ? 'استئناف' : 'إيقاف مؤقت'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
        ),
      ],
    );
  }
}

