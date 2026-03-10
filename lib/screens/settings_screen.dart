import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _audio = AudioService.instance;
  bool _musicEnabled = true;
  bool _announcementsEnabled = true;
  double _volume = 0.8;
  String _selectedTrack = 'motivational';
  bool _darkMode = false;
  String _distanceUnit = 'km';
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _musicEnabled = _audio.isMusicEnabled;
    _announcementsEnabled = _audio.isAnnouncementsEnabled;
    _volume = _audio.volume;
    _selectedTrack = _audio.selectedTrack;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // إعدادات الصوت
          _sectionHeader(theme, Icons.music_note, 'الصوت والموسيقى'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('تشغيل الموسيقى'),
                  subtitle: const Text('موسيقى خلفية أثناء المشي'),
                  value: _musicEnabled,
                  secondary: const Icon(Icons.music_note),
                  onChanged: (v) {
                    setState(() => _musicEnabled = v);
                    _audio.setMusicEnabled(v);
                  },
                ),
                if (_musicEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('اختر نوع الموسيقى', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: AudioService.availableTracks.entries.map((e) =>
                            ChoiceChip(
                              label: Text(e.value),
                              selected: _selectedTrack == e.key,
                              onSelected: (_) {
                                setState(() => _selectedTrack = e.key);
                                _audio.setTrack(e.key);
                              },
                            )
                          ).toList(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_down, size: 20),
                        Expanded(
                          child: Slider(
                            value: _volume,
                            onChanged: (v) {
                              setState(() => _volume = v);
                              _audio.setVolume(v);
                            },
                          ),
                        ),
                        const Icon(Icons.volume_up, size: 20),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('الإعلانات الصوتية'),
                  subtitle: const Text('إشعارات بالمسافة والوقت'),
                  value: _announcementsEnabled,
                  secondary: const Icon(Icons.record_voice_over),
                  onChanged: (v) {
                    setState(() => _announcementsEnabled = v);
                    _audio.setAnnouncementsEnabled(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // إعدادات العرض
          _sectionHeader(theme, Icons.display_settings, 'العرض'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('الاهتزاز'),
                  subtitle: const Text('اهتزاز عند تحقيق الأهداف'),
                  value: _vibrationEnabled,
                  secondary: const Icon(Icons.vibration),
                  onChanged: (v) => setState(() => _vibrationEnabled = v),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.straighten),
                  title: const Text('وحدة القياس'),
                  subtitle: Text(_distanceUnit == 'km' ? 'كيلومتر / متر' : 'ميل / قدم'),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'km', label: Text('كم')),
                      ButtonSegment(value: 'mi', label: Text('ميل')),
                    ],
                    selected: {_distanceUnit},
                    onSelectionChanged: (v) => setState(() => _distanceUnit = v.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // معلومات عن التطبيق
          _sectionHeader(theme, Icons.info_outline, 'عن التطبيق'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.map),
                  title: const Text('الخرائط'),
                  subtitle: const Text('OpenStreetMap - مجاني ومفتوح المصدر'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info),
                  title: Text('الإصدار'),
                  trailing: Text('1.0.0', style: TextStyle(color: Colors.grey)),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.battery_saver),
                  title: Text('استهلاك البطارية'),
                  subtitle: Text('يستخدم GPS باستمرار أثناء المشي'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // إشعارات الإنجازات
          _sectionHeader(theme, Icons.emoji_events, 'الإنجازات والتذكيرات'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('إشعارات المعالم'),
                  subtitle: const Text('تنبيه عند كل 500م، 1كم، النصف، الهدف'),
                  trailing: Switch(value: true, onChanged: (_) {}),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.wb_sunny),
                  title: const Text('تذكير يومي'),
                  subtitle: const Text('تذكير بالمشي اليومي'),
                  trailing: Switch(value: false, onChanged: (_) {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          )),
        ],
      ),
    );
  }
}
