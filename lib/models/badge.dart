import 'package:flutter/material.dart';

enum BadgeCategory {
  distance,   // مسافة
  steps,      // خطوات
  sessions,   // جلسات
  streak,     // أيام متتالية
  speed,      // سرعة
  special,    // خاصة
}

class WalkBadge {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final BadgeCategory category;
  final double requiredValue;   // القيمة المطلوبة للحصول عليها
  final Color color;
  final int tier;               // 1=برونز 2=فضة 3=ذهب 4=بلاتين

  // حالة الحصول
  final bool earned;
  final DateTime? earnedAt;
  final double progress;        // 0.0 → 1.0

  const WalkBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.category,
    required this.requiredValue,
    required this.color,
    required this.tier,
    this.earned = false,
    this.earnedAt,
    this.progress = 0,
  });

  WalkBadge copyWith({bool? earned, DateTime? earnedAt, double? progress}) =>
      WalkBadge(
        id: id, title: title, description: description, emoji: emoji,
        category: category, requiredValue: requiredValue, color: color,
        tier: tier,
        earned: earned ?? this.earned,
        earnedAt: earnedAt ?? this.earnedAt,
        progress: progress ?? this.progress,
      );

  String get tierLabel {
    switch (tier) {
      case 1: return 'برونز 🥉';
      case 2: return 'فضة 🥈';
      case 3: return 'ذهب 🥇';
      case 4: return 'بلاتين 💎';
      default: return '';
    }
  }

  Color get tierColor {
    switch (tier) {
      case 1: return const Color(0xFFCD7F32);
      case 2: return const Color(0xFFC0C0C0);
      case 3: return const Color(0xFFFFD700);
      case 4: return const Color(0xFFE5E4E2);
      default: return Colors.grey;
    }
  }

  String get categoryLabel {
    switch (category) {
      case BadgeCategory.distance: return 'مسافة';
      case BadgeCategory.steps:    return 'خطوات';
      case BadgeCategory.sessions: return 'جلسات';
      case BadgeCategory.streak:   return 'انتظام';
      case BadgeCategory.speed:    return 'سرعة';
      case BadgeCategory.special:  return 'خاصة';
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'earned': earned ? 1 : 0,
    'earnedAt': earnedAt?.toIso8601String(),
    'progress': progress,
  };
}

// ─── تعريف جميع الشارات ──────────────────────────────────────────────────────
class BadgeDefinitions {

  static final List<WalkBadge> all = [

    // ── مسافة كل 100م ─────────────────────────────────
    const WalkBadge(id: 'd_100',   title: 'الخطوة الأولى',   emoji: '👣', description: 'امشِ 100 متر',      category: BadgeCategory.distance, requiredValue: 100,    color: Color(0xFF4CAF50), tier: 1),
    const WalkBadge(id: 'd_200',   title: 'متحرك',            emoji: '🚶', description: 'امشِ 200 متر',      category: BadgeCategory.distance, requiredValue: 200,    color: Color(0xFF4CAF50), tier: 1),
    const WalkBadge(id: 'd_300',   title: 'على الطريق',       emoji: '🛤️', description: 'امشِ 300 متر',      category: BadgeCategory.distance, requiredValue: 300,    color: Color(0xFF4CAF50), tier: 1),
    const WalkBadge(id: 'd_400',   title: 'ربع كيلو',         emoji: '📏', description: 'امشِ 400 متر',      category: BadgeCategory.distance, requiredValue: 400,    color: Color(0xFF4CAF50), tier: 1),
    const WalkBadge(id: 'd_500',   title: 'نصف كيلو',         emoji: '🌿', description: 'امشِ 500 متر',      category: BadgeCategory.distance, requiredValue: 500,    color: Color(0xFF66BB6A), tier: 1),
    const WalkBadge(id: 'd_600',   title: 'ستة أعشار',        emoji: '🌱', description: 'امشِ 600 متر',      category: BadgeCategory.distance, requiredValue: 600,    color: Color(0xFF66BB6A), tier: 1),
    const WalkBadge(id: 'd_700',   title: 'جهد مستمر',        emoji: '💪', description: 'امشِ 700 متر',      category: BadgeCategory.distance, requiredValue: 700,    color: Color(0xFF66BB6A), tier: 1),
    const WalkBadge(id: 'd_800',   title: 'ثمانمائة',         emoji: '🏅', description: 'امشِ 800 متر',      category: BadgeCategory.distance, requiredValue: 800,    color: Color(0xFF66BB6A), tier: 1),
    const WalkBadge(id: 'd_900',   title: 'قاب قوسين',        emoji: '🔥', description: 'امشِ 900 متر',      category: BadgeCategory.distance, requiredValue: 900,    color: Color(0xFF66BB6A), tier: 1),
    const WalkBadge(id: 'd_1k',    title: 'كيلومتر كامل',     emoji: '🌟', description: 'امشِ 1 كيلومتر',    category: BadgeCategory.distance, requiredValue: 1000,   color: Color(0xFF2196F3), tier: 2),
    const WalkBadge(id: 'd_2k',    title: 'المتسلق',          emoji: '⛰️', description: 'امشِ 2 كيلومتر',   category: BadgeCategory.distance, requiredValue: 2000,   color: Color(0xFF2196F3), tier: 2),
    const WalkBadge(id: 'd_3k',    title: 'العداء الخفيف',    emoji: '🏃', description: 'امشِ 3 كيلومتر',   category: BadgeCategory.distance, requiredValue: 3000,   color: Color(0xFF2196F3), tier: 2),
    const WalkBadge(id: 'd_5k',    title: 'الخمسة كيلو',      emoji: '🎽', description: 'امشِ 5 كيلومتر',   category: BadgeCategory.distance, requiredValue: 5000,   color: Color(0xFFFF9800), tier: 3),
    const WalkBadge(id: 'd_10k',   title: 'العشرة الكبرى',    emoji: '🏆', description: 'امشِ 10 كيلومتر',  category: BadgeCategory.distance, requiredValue: 10000,  color: Color(0xFFFF9800), tier: 3),
    const WalkBadge(id: 'd_21k',   title: 'نصف ماراثون',      emoji: '🌈', description: 'امشِ 21 كيلومتر',  category: BadgeCategory.distance, requiredValue: 21097,  color: Color(0xFF9C27B0), tier: 4),
    const WalkBadge(id: 'd_42k',   title: 'الماراثون',        emoji: '👑', description: 'امشِ 42 كيلومتر',  category: BadgeCategory.distance, requiredValue: 42195,  color: Color(0xFF9C27B0), tier: 4),

    // ── إجمالي مسافة تراكمية ──────────────────────────
    const WalkBadge(id: 'td_10k',  title: 'عاشق المشي',      emoji: '❤️', description: 'إجمالي 10 كم عبر جميع الجلسات',  category: BadgeCategory.distance, requiredValue: 10000,  color: Color(0xFFE91E63), tier: 2),
    const WalkBadge(id: 'td_50k',  title: 'المسافر',          emoji: '🗺️', description: 'إجمالي 50 كم عبر جميع الجلسات', category: BadgeCategory.distance, requiredValue: 50000,  color: Color(0xFFE91E63), tier: 3),
    const WalkBadge(id: 'td_100k', title: 'المئة كيلو',       emoji: '🌍', description: 'إجمالي 100 كم',                   category: BadgeCategory.distance, requiredValue: 100000, color: Color(0xFFE91E63), tier: 4),

    // ── خطوات في جلسة واحدة ───────────────────────────
    const WalkBadge(id: 's_1k',    title: 'ألف خطوة',         emoji: '👟', description: '1,000 خطوة في جلسة',  category: BadgeCategory.steps, requiredValue: 1000,  color: Color(0xFF00BCD4), tier: 1),
    const WalkBadge(id: 's_5k',    title: 'خمسة آلاف',        emoji: '🦶', description: '5,000 خطوة في جلسة',  category: BadgeCategory.steps, requiredValue: 5000,  color: Color(0xFF00BCD4), tier: 2),
    const WalkBadge(id: 's_10k',   title: 'عشرة آلاف خطوة',  emoji: '🌠', description: '10,000 خطوة في جلسة', category: BadgeCategory.steps, requiredValue: 10000, color: Color(0xFF00BCD4), tier: 3),

    // ── عدد الجلسات ───────────────────────────────────
    const WalkBadge(id: 'ss_1',    title: 'المبتدئ',           emoji: '🌅', description: 'أنهِ أول جلسة مشي',  category: BadgeCategory.sessions, requiredValue: 1,  color: Color(0xFFFF5722), tier: 1),
    const WalkBadge(id: 'ss_5',    title: 'المواظب',           emoji: '📅', description: 'أنهِ 5 جلسات',       category: BadgeCategory.sessions, requiredValue: 5,  color: Color(0xFFFF5722), tier: 1),
    const WalkBadge(id: 'ss_10',   title: 'المنتظم',           emoji: '🗓️', description: 'أنهِ 10 جلسات',      category: BadgeCategory.sessions, requiredValue: 10, color: Color(0xFFFF5722), tier: 2),
    const WalkBadge(id: 'ss_30',   title: 'الشهري',            emoji: '📆', description: 'أنهِ 30 جلسة',       category: BadgeCategory.sessions, requiredValue: 30, color: Color(0xFFFF5722), tier: 3),
    const WalkBadge(id: 'ss_100',  title: 'المئوي',            emoji: '💯', description: 'أنهِ 100 جلسة',      category: BadgeCategory.sessions, requiredValue: 100,color: Color(0xFFFF5722), tier: 4),

    // ── سرعة ──────────────────────────────────────────
    const WalkBadge(id: 'sp_5',    title: 'الخطوة السريعة',   emoji: '⚡', description: 'حافظ على 5 كم/س لجلسة كاملة',  category: BadgeCategory.speed, requiredValue: 5,  color: Color(0xFFFFEB3B), tier: 2),
    const WalkBadge(id: 'sp_7',    title: 'الريح الخفيفة',    emoji: '🌬️', description: 'حافظ على 7 كم/س لجلسة كاملة', category: BadgeCategory.speed, requiredValue: 7,  color: Color(0xFFFFEB3B), tier: 3),

    // ── خاصة ──────────────────────────────────────────
    const WalkBadge(id: 'sp_early', title: 'الصباح الباكر',   emoji: '🌄', description: 'امشِ قبل الساعة 7 صباحاً',     category: BadgeCategory.special, requiredValue: 1, color: Color(0xFFFF9800), tier: 2),
    const WalkBadge(id: 'sp_night', title: 'سارق الليل',      emoji: '🌙', description: 'امشِ بعد الساعة 9 مساءً',      category: BadgeCategory.special, requiredValue: 1, color: Color(0xFF3F51B5), tier: 2),
    const WalkBadge(id: 'sp_rt',    title: 'العودة للبداية',  emoji: '🔄', description: 'أنهِ رحلة ذهاب وإياب',          category: BadgeCategory.special, requiredValue: 1, color: Color(0xFF009688), tier: 2),
  ];

  static WalkBadge? findById(String id) {
    try { return all.firstWhere((b) => b.id == id); } catch (_) { return null; }
  }
}
