import 'package:flutter/material.dart';
import '../services/radio_service.dart';
import '../models/radio_station.dart';
import '../screens/radio_screen.dart';

class MiniRadioPlayer extends StatefulWidget {
  const MiniRadioPlayer({super.key});
  @override
  State<MiniRadioPlayer> createState() => _MiniRadioPlayerState();
}

class _MiniRadioPlayerState extends State<MiniRadioPlayer> {
  final _radio = RadioService.instance;
  RadioState _state = RadioState.stopped;
  RadioStation? _station;

  @override
  void initState() {
    super.initState();
    _state = _radio.state;
    _station = _radio.currentStation;
    _radio.onStateChanged  = (s) { if (mounted) setState(() => _state = s); };
    _radio.onStationChanged = (s) { if (mounted) setState(() => _station = s); };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_station == null && _state == RadioState.stopped) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RadioScreen())),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceVariant,
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.radio, size: 20),
            SizedBox(width: 8),
            Text('اضغط لتشغيل الراديو أثناء المشي', style: TextStyle(fontSize: 13)),
            Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14),
          ]),
        ),
      );
    }

    final isPlaying = _state == RadioState.playing;
    final isLoading = _state == RadioState.loading;
    final color = _colorFor(_station);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RadioScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(colors: [color, color.withOpacity(0.7)],
            begin: Alignment.centerLeft, end: Alignment.centerRight),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)],
        ),
        child: Row(children: [
          Text(_station?.flag ?? '📻', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
            Text(_station?.name ?? 'راديو',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(isPlaying ? '🔴 يبث الآن' : isLoading ? 'جارٍ التحميل...' : 'متوقف',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
          ])),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: isLoading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 28),
            onPressed: () {
              if (isPlaying) _radio.stop();
              else if (_station != null) _radio.play(_station!);
            },
          ),
        ]),
      ),
    );
  }

  Color _colorFor(RadioStation? s) {
    if (s == null) return const Color(0xFF2ECC71);
    switch (s.id) {
      case 'sy_orient':     return const Color(0xFF1565C0);
      case 'sy_rotana_sham':return const Color(0xFFAD1457);
      case 'sy_fm_damascus':return const Color(0xFF00695C);
      case 'sy_sham_fm':    return const Color(0xFF4527A0);
      case 'sy_ninar':      return const Color(0xFF37474F);
      case 'sy_art_music':  return const Color(0xFFC62828);
      case 'ar_quran':      return const Color(0xFF1B5E20);
      default: return s.isCustom ? const Color(0xFF00695C) : const Color(0xFF546E7A);
    }
  }
}
