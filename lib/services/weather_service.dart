import 'dart:convert';
import 'package:flutter/material.dart' show Color;
import 'package:http/http.dart' as http;

// ─── نماذج البيانات ──────────────────────────────────────────────────────────

class WeatherData {
  final double temperature;
  final double feelsLike;
  final double humidity;
  final double windSpeed;
  final double uvIndex;
  final int weatherCode;
  final bool isDay;
  final DateTime fetchTime;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.uvIndex,
    required this.weatherCode,
    required this.isDay,
    required this.fetchTime,
  });

  bool get isStale => DateTime.now().difference(fetchTime).inMinutes > 30;

  String get description {
    if (weatherCode == 0)  return 'صحو تام';
    if (weatherCode == 1)  return 'صحو في الغالب';
    if (weatherCode == 2)  return 'غيوم جزئية';
    if (weatherCode == 3)  return 'غائم';
    if (weatherCode <= 49) return 'ضباب';
    if (weatherCode <= 59) return 'رذاذ خفيف';
    if (weatherCode <= 69) return 'أمطار';
    if (weatherCode <= 79) return 'ثلج';
    if (weatherCode <= 82) return 'زخات مطر';
    if (weatherCode <= 99) return 'عواصف رعدية';
    return 'طقس متغير';
  }

  String get emoji {
    if (weatherCode == 0)  return isDay ? '☀️' : '🌙';
    if (weatherCode <= 2)  return isDay ? '🌤️' : '🌙';
    if (weatherCode == 3)  return '☁️';
    if (weatherCode <= 49) return '🌫️';
    if (weatherCode <= 59) return '🌦️';
    if (weatherCode <= 69) return '🌧️';
    if (weatherCode <= 79) return '❄️';
    if (weatherCode <= 82) return '🌦️';
    if (weatherCode <= 99) return '⛈️';
    return '🌡️';
  }

  WalkAdvice get walkAdvice {
    if (temperature > 38) return WalkAdvice(
      suitable: false, emoji: '🥵', title: 'حرارة شديدة!',
      message: 'درجة الحرارة خطيرة، تجنب المشي في الخارج تماماً',
      color: const Color(0xFFE53935));
    if (temperature > 32) return WalkAdvice(
      suitable: true, emoji: '⚠️', title: 'حار — كن حذراً',
      message: 'اشرب ماءً كثيراً، امشِ صباحاً أو مساءً',
      color: const Color(0xFFFF6F00));
    if (weatherCode >= 61 && weatherCode <= 69) return WalkAdvice(
      suitable: false, emoji: '🌧️', title: 'أمطار حالياً',
      message: 'ينصح بالانتظار حتى ينقشع المطر',
      color: const Color(0xFF1565C0));
    if (weatherCode >= 80) return WalkAdvice(
      suitable: false, emoji: '⛈️', title: 'عواصف!',
      message: 'الطقس خطير، لا تخرج',
      color: const Color(0xFF6A1B9A));
    if (windSpeed > 45) return WalkAdvice(
      suitable: true, emoji: '💨', title: 'رياح قوية',
      message: 'رياح مرتفعة، تجنب المناطق المكشوفة',
      color: const Color(0xFF00838F));
    if (humidity > 85) return WalkAdvice(
      suitable: true, emoji: '💧', title: 'رطوبة عالية',
      message: 'الجو رطب جداً، اشرب ماءً إضافياً',
      color: const Color(0xFF0277BD));
    if (temperature < 5) return WalkAdvice(
      suitable: true, emoji: '🧥', title: 'طقس بارد',
      message: 'ارتدِ ملابس دافئة وسخّن عضلاتك قبل البدء',
      color: const Color(0xFF4527A0));
    if (weatherCode <= 2 && temperature >= 18 && temperature <= 28) return WalkAdvice(
      suitable: true, emoji: '✅', title: 'طقس مثالي للمشي!',
      message: 'الجو رائع، وقت ممتاز للخروج والاستمتاع',
      color: const Color(0xFF2E7D32));
    return WalkAdvice(
      suitable: true, emoji: '👟', title: 'يمكنك المشي',
      message: 'الطقس مقبول للمشي الخارجي',
      color: const Color(0xFF00695C));
  }
}

class WalkAdvice {
  final bool suitable;
  final String emoji;
  final String title;
  final String message;
  final Color color;
  const WalkAdvice({
    required this.suitable, required this.emoji,
    required this.title,   required this.message, required this.color,
  });
}

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final int weatherCode;
  final double precipitation;

  const HourlyForecast({
    required this.time, required this.temperature,
    required this.weatherCode, required this.precipitation,
  });

  String get emoji {
    if (weatherCode == 0)  return '☀️';
    if (weatherCode <= 2)  return '🌤️';
    if (weatherCode == 3)  return '☁️';
    if (weatherCode <= 49) return '🌫️';
    if (weatherCode <= 69) return '🌧️';
    if (weatherCode <= 79) return '❄️';
    if (weatherCode <= 99) return '⛈️';
    return '🌡️';
  }
}

// ─── الخدمة ──────────────────────────────────────────────────────────────────

class WeatherService {
  static final WeatherService instance = WeatherService._();
  WeatherService._();

  WeatherData? _cached;
  double? _lastLat;

  static const _weatherBase = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherData?> getWeather(double lat, double lng) async {
    if (_cached != null && !_cached!.isStale &&
        _lastLat != null && (lat - _lastLat!).abs() < 0.05) {
      return _cached;
    }
    try {
      final uri = Uri.parse(_weatherBase).replace(queryParameters: {
        'latitude':  lat.toStringAsFixed(4),
        'longitude': lng.toStringAsFixed(4),
        'current': [
          'temperature_2m', 'apparent_temperature',
          'relative_humidity_2m', 'wind_speed_10m',
          'weather_code', 'uv_index', 'is_day',
        ].join(','),
        'forecast_days': '1',
        'timezone': 'auto',
        'wind_speed_unit': 'kmh',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return _cached;

      final j = jsonDecode(res.body);
      final c = j['current'] as Map<String, dynamic>;
      _cached = WeatherData(
        temperature: (c['temperature_2m']       as num).toDouble(),
        feelsLike:   (c['apparent_temperature'] as num).toDouble(),
        humidity:    (c['relative_humidity_2m'] as num).toDouble(),
        windSpeed:   (c['wind_speed_10m']        as num).toDouble(),
        uvIndex:     (c['uv_index']              as num? ?? 0).toDouble(),
        weatherCode: c['weather_code']           as int,
        isDay:       (c['is_day']                as int) == 1,
        fetchTime:   DateTime.now(),
      );
      _lastLat = lat;
      return _cached;
    } catch (_) {
      return _cached;
    }
  }

  Future<List<HourlyForecast>> getHourly(double lat, double lng) async {
    try {
      final uri = Uri.parse(_weatherBase).replace(queryParameters: {
        'latitude':  lat.toStringAsFixed(4),
        'longitude': lng.toStringAsFixed(4),
        'hourly': 'temperature_2m,weather_code,precipitation_probability',
        'forecast_days': '1',
        'timezone': 'auto',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final j = jsonDecode(res.body);
      final h = j['hourly'] as Map<String, dynamic>;
      final times  = h['time']                     as List;
      final temps  = h['temperature_2m']            as List;
      final codes  = h['weather_code']              as List;
      final precip = h['precipitation_probability'] as List;

      final now = DateTime.now();
      final result = <HourlyForecast>[];
      for (int i = 0; i < times.length && result.length < 12; i++) {
        final t = DateTime.parse(times[i] as String);
        if (t.isAfter(now.subtract(const Duration(minutes: 30)))) {
          result.add(HourlyForecast(
            time:          t,
            temperature:   (temps[i]  as num).toDouble(),
            weatherCode:   codes[i]   as int,
            precipitation: (precip[i] as num).toDouble(),
          ));
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }
}

// ─── توقعات يومية ─────────────────────────────────────────────────────────

class DailyForecast {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final int weatherCode;

  const DailyForecast({
    required this.date, required this.tempMax,
    required this.tempMin, required this.weatherCode,
  });

  String get emoji {
    if (weatherCode == 0)  return '☀️';
    if (weatherCode <= 2)  return '🌤️';
    if (weatherCode == 3)  return '☁️';
    if (weatherCode <= 49) return '🌫️';
    if (weatherCode <= 69) return '🌧️';
    if (weatherCode <= 79) return '❄️';
    if (weatherCode <= 99) return '⛈️';
    return '🌡️';
  }

  String get description {
    if (weatherCode == 0)  return 'صحو تام';
    if (weatherCode <= 2)  return 'صحو جزئي';
    if (weatherCode == 3)  return 'غائم';
    if (weatherCode <= 49) return 'ضباب';
    if (weatherCode <= 59) return 'رذاذ';
    if (weatherCode <= 69) return 'أمطار';
    if (weatherCode <= 79) return 'ثلج';
    if (weatherCode <= 82) return 'زخات';
    if (weatherCode <= 99) return 'عواصف';
    return 'متغير';
  }
}

extension WeatherServiceDaily on WeatherService {
  Future<List<DailyForecast>> getDaily(double lat, double lng) async {
    try {
      final uri = Uri.parse(WeatherService._weatherBase).replace(queryParameters: {
        'latitude':  lat.toStringAsFixed(4),
        'longitude': lng.toStringAsFixed(4),
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
        'forecast_days': '7',
        'timezone': 'auto',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final j = jsonDecode(res.body);
      final d = j['daily'] as Map<String, dynamic>;
      final dates    = d['time']                as List;
      final maxTemps = d['temperature_2m_max']  as List;
      final minTemps = d['temperature_2m_min']  as List;
      final codes    = d['weather_code']        as List;

      return List.generate(dates.length, (i) => DailyForecast(
        date:        DateTime.parse(dates[i] as String),
        tempMax:     (maxTemps[i] as num).toDouble(),
        tempMin:     (minTemps[i] as num).toDouble(),
        weatherCode: codes[i] as int,
      ));
    } catch (_) {
      return [];
    }
  }
}