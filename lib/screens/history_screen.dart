import 'package:flutter/material.dart';
import '../models/walk_session.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import 'map_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<WalkSession> _sessions = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final sessions = await DatabaseService.instance.getWalkSessions();
    final stats = await DatabaseService.instance.getStats();
    setState(() {
      _sessions = sessions;
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _deleteSession(int id) async {
    await DatabaseService.instance.deleteWalkSession(id);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الجلسات'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // إحصائيات إجمالية
                    if (_stats.isNotEmpty) _buildTotalStats(theme),
                    const SizedBox(height: 16),
                    
                    Text('الجلسات السابقة',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    
                    if (_sessions.isEmpty)
                      _buildEmptyState(theme)
                    else
                      ..._sessions.map((session) => _buildSessionCard(theme, session)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTotalStats(ThemeData theme) {
    final totalKm = ((_stats['totalDistance'] as double? ?? 0) / 1000);
    
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإجمالي الكلي',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              )),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _totalStat(theme, '${_stats['totalSessions'] ?? 0}', 'جلسة', Icons.directions_walk),
                _totalStat(theme, totalKm.toStringAsFixed(1), 'كم', Icons.map),
                _totalStat(theme, '${_stats['totalSteps'] ?? 0}', 'خطوة', Icons.directions_walk),
                _totalStat(theme, '${(_stats['totalCalories'] as double? ?? 0).toStringAsFixed(0)}', 'سعرة', Icons.local_fire_department),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalStat(ThemeData theme, String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        )),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
        )),
      ],
    );
  }

  Widget _buildSessionCard(ThemeData theme, WalkSession session) {
    final date = session.date;
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: true ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        true ? '✓ مكتملة' : '⚠ غير مكتملة',
                        style: TextStyle(
                          fontSize: 12,
                          color: true ? Colors.green.shade800 : Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        session.tripType == 'round_trip' ? '↔ ذهاب وإياب' : '→ ذهاب',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                PopupMenuButton(
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'map', child: Row(
                      children: [Icon(Icons.map, size: 18), SizedBox(width: 8), Text('عرض الخريطة')],
                    )),
                    const PopupMenuItem(value: 'delete', child: Row(
                      children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('حذف', style: TextStyle(color: Colors.red))],
                    )),
                  ],
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await _deleteSession(session.id!);
                    } else if (value == 'map') {
                      final points = LocationService.decodeRoutePoints(session.routePoints);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MapScreen(routePoints: points),
                      ));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$dateStr - $timeStr', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sessionStat(Icons.straighten, session.distanceFormatted, 'المسافة'),
                _sessionStat(Icons.timer, session.durationFormatted, 'الوقت'),
                _sessionStat(Icons.directions_walk, '${session.steps}', 'الخطوات'),
                _sessionStat(Icons.local_fire_department, '${session.calories.toString()}', 'سعرة'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.directions_walk, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('لا توجد جلسات بعد',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('ابدأ جلسة مشي جديدة من الصفحة الرئيسية',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

extension on Icons {
  static const IconData footprint = Icons.directions_walk;
}
