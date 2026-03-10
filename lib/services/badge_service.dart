import 'package:sqflite/sqflite.dart';
import '../models/badge.dart';
import '../models/walk_session.dart';
import 'database_service.dart';

class BadgeService {
  static final BadgeService instance = BadgeService._init();
  BadgeService._init();

  // ─── قراءة حالة كل الشارات من DB ────────────────────────────────────────
  Future<List<WalkBadge>> getAllBadges() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('badges');
    final earnedMap = { for (var r in rows) r['id'] as String : r };

    return BadgeDefinitions.all.map((badge) {
      final row = earnedMap[badge.id];
      if (row == null) return badge;
      return badge.copyWith(
        earned: row['earned'] == 1,
        earnedAt: row['earnedAt'] != null ? DateTime.tryParse(row['earnedAt'] as String) : null,
        progress: (row['progress'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Future<List<WalkBadge>> getEarnedBadges() async {
    final all = await getAllBadges();
    return all.where((b) => b.earned).toList();
  }

  // ─── تقييم الجلسة واستخراج شارات جديدة ──────────────────────────────────
  Future<List<WalkBadge>> evaluateSession(WalkSession session, {
    required int totalSessions,
    required double totalDistanceAllTime,
  }) async {
    final db = await DatabaseService.instance.database;
    final existing = { for (var r in await db.query('badges')) r['id'] as String : r };
    final newlyEarned = <WalkBadge>[];

    Future<void> tryEarn(WalkBadge badge, double progress) async {
      if (existing[badge.id]?['earned'] == 1) return; // محفوظة مسبقاً
      final earned = progress >= 1.0;
      final data = {
        'id': badge.id,
        'earned': earned ? 1 : 0,
        'earnedAt': earned ? DateTime.now().toIso8601String() : null,
        'progress': progress.clamp(0.0, 1.0),
      };
      await db.insert('badges', data, conflictAlgorithm: ConflictAlgorithm.replace);
      if (earned) {
        newlyEarned.add(badge.copyWith(earned: true, earnedAt: DateTime.now(), progress: 1.0));
      }
    }

    final hour = session.date.hour;

    for (final badge in BadgeDefinitions.all) {
      switch (badge.id) {

        // ── مسافة في جلسة واحدة (100م → 42كم) ──────────
        case 'd_100': case 'd_200': case 'd_300': case 'd_400': case 'd_500':
        case 'd_600': case 'd_700': case 'd_800': case 'd_900':
        case 'd_1k':  case 'd_2k':  case 'd_3k':  case 'd_5k':
        case 'd_10k': case 'd_21k': case 'd_42k':
          await tryEarn(badge, session.distance / badge.requiredValue);
          break;

        // ── مسافة تراكمية ────────────────────────────────
        case 'td_10k': case 'td_50k': case 'td_100k':
          await tryEarn(badge, totalDistanceAllTime / badge.requiredValue);
          break;

        // ── خطوات ────────────────────────────────────────
        case 's_1k': case 's_5k': case 's_10k':
          await tryEarn(badge, session.steps / badge.requiredValue);
          break;

        // ── جلسات ────────────────────────────────────────
        case 'ss_1': case 'ss_5': case 'ss_10': case 'ss_30': case 'ss_100':
          await tryEarn(badge, totalSessions / badge.requiredValue);
          break;

        // ── سرعة متوسطة ─────────────────────────────────
        case 'sp_5': case 'sp_7':
          await tryEarn(badge, session.avgSpeed >= badge.requiredValue ? 1.0 : session.avgSpeed / badge.requiredValue);
          break;

        // ── خاصة ─────────────────────────────────────────
        case 'sp_early':
          if (hour < 7) await tryEarn(badge, 1.0);
          break;
        case 'sp_night':
          if (hour >= 21) await tryEarn(badge, 1.0);
          break;
        case 'sp_rt':
          if (session.tripType == 'round_trip' && true) await tryEarn(badge, 1.0);
          break;
      }
    }

    return newlyEarned;
  }

  // ─── لحظية أثناء المشي: شارات تُعطى عند كل 100م ────────────────────────
  /// يُستدعى من home_screen كلما تغيرت المسافة
  /// يُرجع الشارة إذا وصل المستخدم لمعلم جديد، وإلا null
  WalkBadge? checkLiveMilestone(double previousDistance, double currentDistance) {
    // نبحث عن أي شارة مسافة عبر حدودها بين القيمتين
    final distanceBadges = BadgeDefinitions.all.where(
      (b) => b.category == BadgeCategory.distance && b.id.startsWith('d_'),
    );
    for (final badge in distanceBadges) {
      if (previousDistance < badge.requiredValue && currentDistance >= badge.requiredValue) {
        return badge;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> getBadgeStats() async {
    final all = await getAllBadges();
    final earned = all.where((b) => b.earned).length;
    return {
      'total': all.length,
      'earned': earned,
      'percentage': all.isEmpty ? 0.0 : earned / all.length,
    };
  }
}
