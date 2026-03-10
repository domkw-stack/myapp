import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/radio_station.dart';

enum RadioState { stopped, loading, playing, error }

class RadioService {
  static final RadioService instance = RadioService._init();
  RadioService._init();

  final AudioPlayer _player = AudioPlayer();

  RadioStation? _currentStation;
  RadioState _state = RadioState.stopped;
  double _volume = 0.8;
  List<String> _favoriteIds = [];
  List<RadioStation> _customStations = [];
  List<RadioStation> _recentStations = [];

  Function(RadioState)? onStateChanged;
  Function(RadioStation?)? onStationChanged;
  Function(String)? onError;

  RadioStation? get currentStation => _currentStation;
  RadioState get state => _state;
  double get volume => _volume;
  bool get isPlaying => _state == RadioState.playing;
  bool get isLoading => _state == RadioState.loading;
  List<RadioStation> get customStations => List.unmodifiable(_customStations);
  List<RadioStation> get recentStations => List.unmodifiable(_recentStations);

  List<RadioStation> get favoriteStations {
    final all = [...RadioStations.all, ..._customStations];
    return all.where((s) => _favoriteIds.contains(s.id)).toList();
  }

  Future<void> init() async {
    await _loadPrefs();

    _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        _updateState(RadioState.playing);
      } else if (state == PlayerState.stopped || state == PlayerState.completed) {
        if (_state != RadioState.error) _updateState(RadioState.stopped);
      }
    });

    // إعادة الاتصال التلقائية
    _player.onPlayerComplete.listen((_) {
      if (_currentStation != null) {
        Future.delayed(const Duration(seconds: 3), () {
          if (_currentStation != null) play(_currentStation!);
        });
      }
    });
  }

  Future<void> play(RadioStation station) async {
    try {
      _updateState(RadioState.loading);
      _currentStation = station;
      onStationChanged?.call(station);

      _recentStations.removeWhere((s) => s.id == station.id);
      _recentStations.insert(0, station);
      if (_recentStations.length > 8) _recentStations.removeLast();

      await _player.stop();
      await _player.setVolume(_volume);
      await _player.play(UrlSource(station.streamUrl));
    } catch (e) {
      _updateState(RadioState.error);
      onError?.call('تعذر تشغيل ${station.name}');
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _currentStation = null;
    onStationChanged?.call(null);
    _updateState(RadioState.stopped);
  }

  void setVolume(double vol) {
    _volume = vol;
    _player.setVolume(vol);
  }

  bool isFavorite(RadioStation s) => _favoriteIds.contains(s.id);

  Future<void> toggleFavorite(RadioStation station) async {
    if (_favoriteIds.contains(station.id)) {
      _favoriteIds.remove(station.id);
    } else {
      _favoriteIds.add(station.id);
    }
    await _savePrefs();
  }

  Future<void> addCustomStation(RadioStation station) async {
    _customStations.removeWhere((s) => s.id == station.id);
    _customStations.add(station);
    await _savePrefs();
  }

  Future<void> removeCustomStation(String id) async {
    _customStations.removeWhere((s) => s.id == id);
    _favoriteIds.remove(id);
    await _savePrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteIds = prefs.getStringList('radio_favorites') ?? [];
    final customJson = prefs.getStringList('radio_custom') ?? [];
    _customStations = customJson
        .map((j) => RadioStation.fromJson(jsonDecode(j)))
        .toList();
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('radio_favorites', _favoriteIds);
    await prefs.setStringList('radio_custom',
        _customStations.map((s) => jsonEncode(s.toJson())).toList());
  }

  void _updateState(RadioState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }

  void dispose() => _player.dispose();
}
