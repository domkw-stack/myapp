import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/badge.dart';

/// يُعرض فوق شاشة المشي عند كسب شارة جديدة
class BadgePopup extends StatefulWidget {
  final WalkBadge badge;
  final VoidCallback onDismiss;

  const BadgePopup({super.key, required this.badge, required this.onDismiss});

  @override
  State<BadgePopup> createState() => _BadgePopupState();
}

class _BadgePopupState extends State<BadgePopup>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();

    // اهتزاز خفيف
    HapticFeedback.mediumImpact();

    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    _scale = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _fadeCtrl,  curve: Curves.easeIn);

    _scaleCtrl.forward();

    // إغلاق تلقائي بعد 3.5 ثانية
    _autoClose = Timer(const Duration(milliseconds: 3500), _dismiss);
  }

  void _dismiss() {
    _fadeCtrl.forward().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _scaleCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badge;

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(_fade),
      child: GestureDetector(
        onTap: _dismiss,
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: b.color.withOpacity(0.35),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
                border: Border.all(color: b.tierColor, width: 3),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // نص "شارة جديدة"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [b.color, b.color.withOpacity(0.7)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('شارة جديدة! 🎉',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // الأيقونة مع توهج
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [b.color, b.color.withOpacity(0.5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [BoxShadow(color: b.color.withOpacity(0.5), blurRadius: 20, spreadRadius: 4)],
                      border: Border.all(color: b.tierColor, width: 3),
                    ),
                    child: Center(child: Text(b.emoji, style: const TextStyle(fontSize: 40))),
                  ),
                  const SizedBox(height: 12),

                  Text(b.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(b.description,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 8),

                  // مستوى الشارة
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: b.tierColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(b.tierLabel,
                      style: TextStyle(color: b.tierColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                  Text('اضغط للإغلاق', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// OverlayEntry مساعد لعرض الـ popup فوق أي شاشة
class BadgePopupHelper {
  static OverlayEntry? _current;

  static void show(BuildContext context, WalkBadge badge) {
    _current?.remove();

    _current = OverlayEntry(
      builder: (_) => Material(
        color: Colors.black.withOpacity(0.4),
        child: BadgePopup(
          badge: badge,
          onDismiss: () {
            _current?.remove();
            _current = null;
          },
        ),
      ),
    );

    Overlay.of(context).insert(_current!);
  }
}
