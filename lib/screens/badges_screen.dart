import 'package:flutter/material.dart';
import '../models/badge.dart';
import '../services/badge_service.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with SingleTickerProviderStateMixin {
  List<WalkBadge> _badges = [];
  bool _loading = true;
  BadgeCategory? _selectedCategory;
  late TabController _tabController;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBadges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    setState(() => _loading = true);
    final badges = await BadgeService.instance.getAllBadges();
    final stats = await BadgeService.instance.getBadgeStats();
    setState(() {
      _badges = badges;
      _stats = stats;
      _loading = false;
    });
  }

  List<WalkBadge> get _filteredBadges {
    if (_selectedCategory == null) return _badges;
    return _badges.where((b) => b.category == _selectedCategory).toList();
  }

  List<WalkBadge> get _earnedBadges => _badges.where((b) => b.earned).toList();
  List<WalkBadge> get _pendingBadges => _badges.where((b) => !b.earned).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('شاراتي'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events), text: 'المحصلة'),
            Tab(icon: Icon(Icons.lock_open),    text: 'المكتسبة'),
            Tab(icon: Icon(Icons.lock),         text: 'القادمة'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(theme),
                _buildEarnedTab(theme),
                _buildPendingTab(theme),
              ],
            ),
    );
  }

  // ─── تبويب الملخص ─────────────────────────────────────────────────────────
  Widget _buildOverviewTab(ThemeData theme) {
    final pct = ((_stats['percentage'] as double? ?? 0) * 100).toStringAsFixed(0);
    final earned = _stats['earned'] as int? ?? 0;
    final total = _stats['total'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ─ بطاقة التقدم الكلي ─
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$earned / $total شارة',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            )),
                          Text('$pct% مكتملة',
                            style: TextStyle(color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8))),
                        ],
                      ),
                      _buildCircularProgress(double.parse(pct) / 100, theme),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_stats['percentage'] as double? ?? 0),
                      minHeight: 12,
                      backgroundColor: theme.colorScheme.onPrimaryContainer.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─ آخر الشارات المكتسبة ─
          if (_earnedBadges.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('آخر الإنجازات', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(onPressed: () => _tabController.animateTo(1), child: const Text('عرض الكل')),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _earnedBadges.reversed.take(6).map((b) => _miniEarnedBadge(b, theme)).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ─ الشارات حسب الفئة ─
          Text('حسب الفئة', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...BadgeCategory.values.map((cat) => _categoryProgressCard(cat, theme)),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(double value, ThemeData theme) {
    return SizedBox(
      width: 70, height: 70,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 8,
            backgroundColor: theme.colorScheme.onPrimaryContainer.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.onPrimaryContainer),
          ),
          Center(
            child: Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniEarnedBadge(WalkBadge b, ThemeData theme) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(left: 10),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [b.color, b.color.withOpacity(0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: b.color.withOpacity(0.4), blurRadius: 8)],
            ),
            child: Center(child: Text(b.emoji, style: const TextStyle(fontSize: 28))),
          ),
          const SizedBox(height: 4),
          Text(b.title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _categoryProgressCard(BadgeCategory cat, ThemeData theme) {
    final catBadges = _badges.where((b) => b.category == cat).toList();
    final catEarned = catBadges.where((b) => b.earned).length;
    final pct = catBadges.isEmpty ? 0.0 : catEarned / catBadges.length;

    final catEmojis = {
      BadgeCategory.distance: '📏',
      BadgeCategory.steps:    '👟',
      BadgeCategory.sessions: '📅',
      BadgeCategory.streak:   '🔥',
      BadgeCategory.speed:    '⚡',
      BadgeCategory.special:  '✨',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(catEmojis[cat] ?? '⭐', style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(catBadges.first.categoryLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text('$catEarned/${catBadges.length}',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── تبويب المكتسبة ───────────────────────────────────────────────────────
  Widget _buildEarnedTab(ThemeData theme) {
    if (_earnedBadges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('لا توجد شارات بعد', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('ابدأ المشي لتكسب أول شارة!',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _earnedBadges.length,
      itemBuilder: (_, i) => _buildBadgeCell(_earnedBadges[i], theme, earned: true),
    );
  }

  // ─── تبويب القادمة ────────────────────────────────────────────────────────
  Widget _buildPendingTab(ThemeData theme) {
    final pending = _pendingBadges;
    if (pending.isEmpty) {
      return const Center(child: Text('🏆 أحسنت! جمعت كل الشارات!'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: pending.map((b) => _buildPendingCard(b, theme)).toList(),
    );
  }

  Widget _buildBadgeCell(WalkBadge b, ThemeData theme, {required bool earned}) {
    return GestureDetector(
      onTap: () => _showBadgeDetail(b),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: earned
                ? LinearGradient(colors: [b.color, b.color.withOpacity(0.6)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
              color: earned ? null : Colors.grey.shade200,
              boxShadow: earned ? [BoxShadow(color: b.color.withOpacity(0.4), blurRadius: 10)] : null,
              border: Border.all(
                color: earned ? b.tierColor : Colors.grey.shade300,
                width: earned ? 3 : 1,
              ),
            ),
            child: Center(
              child: Text(
                b.emoji,
                style: TextStyle(fontSize: 30, color: earned ? null : Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            b.title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: earned ? null : Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(WalkBadge b, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _showBadgeDetail(b),
        leading: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(child: Text(b.emoji, style: const TextStyle(fontSize: 24, color: Colors.grey))),
        ),
        title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b.description, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: b.progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(b.color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(b.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 11, color: b.color, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: b.tierColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(b.tierLabel, style: TextStyle(fontSize: 10, color: b.tierColor, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _showBadgeDetail(WalkBadge b) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: b.earned
                  ? LinearGradient(colors: [b.color, b.color.withOpacity(0.5)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
                color: b.earned ? null : Colors.grey.shade200,
                boxShadow: b.earned ? [BoxShadow(color: b.color.withOpacity(0.5), blurRadius: 20)] : null,
                border: Border.all(color: b.tierColor, width: 3),
              ),
              child: Center(child: Text(b.emoji, style: const TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 12),
            Text(b.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: b.tierColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(b.tierLabel, style: TextStyle(color: b.tierColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Text(b.description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            if (b.earned && b.earnedAt != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('حصلت عليها ${_formatDate(b.earnedAt!)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: b.progress,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(b.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${(b.progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: b.color, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
