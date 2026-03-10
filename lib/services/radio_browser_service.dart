import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/radio_station.dart';

/// Radio Browser API — قاعدة بيانات مجانية 30,000+ محطة
class RadioBrowserService {
  static final RadioBrowserService instance = RadioBrowserService._();
  RadioBrowserService._();

  static const _base = 'https://de1.api.radio-browser.info/json';

  // ─── بحث عن محطات ──────────────────────────────────────────────────────
  Future<List<RadioStation>> search(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '$_base/stations/search'
        '?name=${Uri.encodeComponent(query)}'
        '&limit=$limit&order=votes&reverse=true&hidebroken=true'
      );
      final res = await http.get(uri, headers: {'User-Agent': 'WalkTrackerApp/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final list = jsonDecode(res.body) as List;
      return list.map((j) => _fromJson(j)).whereType<RadioStation>().toList();
    } catch (_) {
      return [];
    }
  }

  // ─── محطات حسب الدولة ──────────────────────────────────────────────────
  Future<List<RadioStation>> byCountry(String countryCode, {int limit = 30}) async {
    try {
      final uri = Uri.parse(
        '$_base/stations/bycountrycodeexact/$countryCode'
        '?limit=$limit&order=votes&reverse=true&hidebroken=true'
      );
      final res = await http.get(uri, headers: {'User-Agent': 'WalkTrackerApp/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final list = jsonDecode(res.body) as List;
      return list.map((j) => _fromJson(j)).whereType<RadioStation>().toList();
    } catch (_) {
      return [];
    }
  }

  // ─── الأكثر تصويتاً عالمياً ────────────────────────────────────────────
  Future<List<RadioStation>> topStations({int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '$_base/stations?limit=$limit&order=votes&reverse=true&hidebroken=true'
      );
      final res = await http.get(uri, headers: {'User-Agent': 'WalkTrackerApp/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final list = jsonDecode(res.body) as List;
      return list.map((j) => _fromJson(j)).whereType<RadioStation>().toList();
    } catch (_) {
      return [];
    }
  }

  RadioStation? _fromJson(Map<String, dynamic> j) {
    final url = (j['url_resolved'] ?? j['url'] ?? '').toString().trim();
    if (url.isEmpty) return null;
    final name = (j['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;

    // رمز العَلَم من رمز الدولة
    final cc = (j['countrycode'] ?? '').toString().toUpperCase();
    final flag = _flag(cc);

    return RadioStation(
      id: 'rb_${j['stationuuid'] ?? name.hashCode}',
      name: name,
      nameEn: name,
      streamUrl: url,
      country: (j['country'] ?? '').toString(),
      flag: flag.isNotEmpty ? flag : '🌍',
      genre: (j['tags'] ?? j['codec'] ?? '').toString().split(',').first,
      description: '${j['votes'] ?? 0} تصويت • ${j['codec'] ?? ''} ${j['bitrate'] ?? ''}kbps',
    );
  }

  String _flag(String cc) {
    if (cc.length != 2) return '';
    final base = 0x1F1E6 - 0x41;
    return String.fromCharCodes([cc.codeUnitAt(0) + base, cc.codeUnitAt(1) + base]);
  }
}
