import 'package:flutter/material.dart';
import 'route_suggestions_screen.dart';
import 'saved_routes_screen.dart';
import '../models/saved_route.dart';

class WalkSetupScreen extends StatefulWidget {
  const WalkSetupScreen({super.key});

  @override
  State<WalkSetupScreen> createState() => _WalkSetupScreenState();
}

class _WalkSetupScreenState extends State<WalkSetupScreen> {
  double _selectedDistance = 2000; // بالأمتار
  String _tripType = 'one_way';
  String _routeType = 'free'; // free, loop, linear

  final List<Map<String, dynamic>> _presets = [
    {'label': '500 م', 'value': 500.0, 'icon': Icons.directions_walk},
    {'label': '1 كم', 'value': 1000.0, 'icon': Icons.directions_walk},
    {'label': '2 كم', 'value': 2000.0, 'icon': Icons.directions_run},
    {'label': '3 كم', 'value': 3000.0, 'icon': Icons.directions_run},
    {'label': '5 كم', 'value': 5000.0, 'icon': Icons.hiking},
    {'label': '10 كم', 'value': 10000.0, 'icon': Icons.hiking},
  ];

  String get _displayDistance {
    if (_selectedDistance >= 1000) {
      return '${(_selectedDistance / 1000).toStringAsFixed(1)} كم';
    }
    return '${_selectedDistance.toStringAsFixed(0)} م';
  }

  String get _totalDistance {
    final total = _tripType == 'round_trip' ? _selectedDistance * 2 : _selectedDistance;
    if (total >= 1000) return '${(total / 1000).toStringAsFixed(1)} كم';
    return '${total.toStringAsFixed(0)} م';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعداد الجلسة'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عرض المسافة المحددة
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        _displayDistance,
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      if (_tripType == 'round_trip') ...[
                        Text(
                          'ذهاب وإياب = $_totalDistance',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // اختصارات المسافة
            Text('اختر مسافة سريعة',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) => ChoiceChip(
                label: Text(preset['label']),
                selected: _selectedDistance == preset['value'],
                onSelected: (_) => setState(() => _selectedDistance = preset['value']),
              )).toList(),
            ),
            const SizedBox(height: 16),

            // شريط تمرير مخصص
            Text('أو حدد مسافة مخصصة',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Slider(
              value: _selectedDistance,
              min: 100,
              max: 42195, // ماراثون
              divisions: 200,
              label: _displayDistance,
              onChanged: (value) => setState(() => _selectedDistance = value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('100 م', style: theme.textTheme.bodySmall),
                Text('42.2 كم', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 20),

            // نوع الرحلة
            Text('نوع الرحلة',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _tripTypeCard(
                    theme,
                    'one_way',
                    Icons.arrow_forward,
                    'ذهاب فقط',
                    'تبدأ وتنهي في نقطة مختلفة',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _tripTypeCard(
                    theme,
                    'round_trip',
                    Icons.loop,
                    'ذهاب وإياب',
                    'تعود لنقطة البداية',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // نوع المسار
            Text('نوع المسار',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...[ 
              {'value': 'free', 'icon': Icons.route, 'label': 'مسار حر', 'desc': 'امشِ حيث تريد'},
              {'value': 'loop', 'icon': Icons.loop, 'label': 'حلقي', 'desc': 'مسار دائري'},
              {'value': 'linear', 'icon': Icons.linear_scale, 'label': 'خطي', 'desc': 'مسار مستقيم'},
            ].map((route) => RadioListTile<String>(
              value: route['value'] as String,
              groupValue: _routeType,
              onChanged: (v) => setState(() => _routeType = v!),
              title: Row(
                children: [
                  Icon(route['icon'] as IconData, size: 20),
                  const SizedBox(width: 8),
                  Text(route['label'] as String),
                ],
              ),
              subtitle: Text(route['desc'] as String),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )).toList(),
            
            const SizedBox(height: 24),

            // ملخص
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ملخص الجلسة', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(),
                    _summaryRow('المسافة الكلية', _totalDistance),
                    _summaryRow('نوع الرحلة', _tripType == 'round_trip' ? 'ذهاب وإياب' : 'ذهاب فقط'),
                    _summaryRow('الخطوات المتوقعة', '${((_tripType == 'round_trip' ? _selectedDistance * 2 : _selectedDistance) / 0.75).toStringAsFixed(0)}'),
                    _summaryRow('السعرات المتوقعة', '${((_tripType == 'round_trip' ? _selectedDistance * 2 : _selectedDistance) / 0.75 * 0.04).toStringAsFixed(0)} سعرة'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── مسارات مقترحة ومحفوظة ───────────────────────────
            Text('اختر مسار',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RouteSuggestionsScreen(
                            targetDistanceMeters: _selectedDistance,
                          ),
                        ),
                      );
                      if (result != null) {
                        Navigator.pop(context, {
                          'distance': result['distance'],
                          'tripType': _tripType,
                          'routeType': 'suggested',
                          'suggestedPoints': result['points'],
                        });
                      }
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('مسارات مقترحة'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SavedRoutesScreen(
                            onRouteSelected: (SavedRoute route) {
                              Navigator.pop(context, {
                                'distance': route.distanceMeters,
                                'tripType': _tripType,
                                'routeType': 'saved',
                                'savedRoute': route,
                              });
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bookmark),
                    label: const Text('مساراتي المحفوظة'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // زر البدء
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context, {
                  'distance': _selectedDistance,
                  'tripType': _tripType,
                  'routeType': _routeType,
                });
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('ابدأ الآن', style: TextStyle(fontSize: 18)),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _tripTypeCard(ThemeData theme, String value, IconData icon, String label, String desc) {
    final selected = _tripType == value;
    return GestureDetector(
      onTap: () => setState(() => _tripType = value),
      child: Card(
        elevation: selected ? 4 : 1,
        color: selected ? theme.colorScheme.primaryContainer : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected ? BorderSide(color: theme.colorScheme.primary, width: 2) : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 32, color: selected ? theme.colorScheme.primary : null),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold,
                color: selected ? theme.colorScheme.primary : null)),
              Text(desc, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
