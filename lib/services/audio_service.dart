import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioService {
  static final AudioService instance = AudioService._init();
  AudioService._init();

  final AudioPlayer _player = AudioPlayer();
  bool _isMusicEnabled = true;
  bool _isAnnouncementsEnabled = true;
  double _volume = 0.8;
  String _selectedTrack = 'motivational';

  bool get isMusicEnabled => _isMusicEnabled;
  bool get isAnnouncementsEnabled => _isAnnouncementsEnabled;
  double get volume => _volume;
  String get selectedTrack => _selectedTrack;

  // أصوات متاحة
  static const Map<String, String> availableTracks = {
    'motivational': 'تحفيزي',
    'nature': 'طبيعة',
    'calm': 'هادئ',
    'beats': 'إيقاع',
  };

  Future<void> playStartSound() async {
    if (!_isAnnouncementsEnabled) return;
    // تشغيل نغمة بدء - يمكن استبدالها بملف صوتي فعلي
    await _player.play(AssetSource('sounds/start.mp3'));
  }

  Future<void> playMilestoneSound() async {
    if (!_isAnnouncementsEnabled) return;
    await _player.play(AssetSource('sounds/milestone.mp3'));
  }

  Future<void> playCompleteSound() async {
    if (!_isAnnouncementsEnabled) return;
    await _player.play(AssetSource('sounds/complete.mp3'));
  }

  Future<void> playBackgroundMusic() async {
    if (!_isMusicEnabled) return;
    await _player.setVolume(_volume);
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/$_selectedTrack.mp3'));
  }

  Future<void> stopMusic() async {
    await _player.stop();
  }

  Future<void> pauseMusic() async {
    await _player.pause();
  }

  Future<void> resumeMusic() async {
    if (_isMusicEnabled) await _player.resume();
  }

  void setVolume(double vol) {
    _volume = vol;
    _player.setVolume(vol);
  }

  void setMusicEnabled(bool enabled) {
    _isMusicEnabled = enabled;
    if (!enabled) _player.stop();
  }

  void setAnnouncementsEnabled(bool enabled) {
    _isAnnouncementsEnabled = enabled;
  }

  void setTrack(String track) {
    _selectedTrack = track;
  }

  void dispose() {
    _player.dispose();
  }
}
