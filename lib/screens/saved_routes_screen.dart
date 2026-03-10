import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/saved_route.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import 'route_preview_screen.dart';

class SavedRoutesScreen extends StatefulWidget {
  final Function(SavedRoute)? onRouteSelected;
  const SavedRoutesScreen({super.key, this.onRouteSelected});

  @override
  State<SavedRoutesScreen> createState() => _SavedRoutesScreenState();
}

class _SavedRoutesScreenState extends State<SavedRoutesScreen>
    with SingleTickerProviderStateMixin {
  List<SavedRoute> _allRoutes = [];
  List<SavedRoute> _favoriteRoutes = [];
  bool _loading = true;
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRoutes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    setState(() => _loading = true);
    final all = await DatabaseService.instance.getSavedRoutes();
    final fav = await DatabaseService.instance.getFavoriteRoutes();
    setState(() {
      _allRoutes = all;
      _favoriteRoutes = fav;
      _loading = false;
    });
  }

  List<SavedRoute> get _filteredRoutes {
    if (_searchQuery.isEmpty) return _allRoutes;
    return _allRoutes
        .where((r) =>
            r.name.contains(_searchQuery) ||
            r.description.contains(_searchQuery))
        .toList();
  }

  Future<void> _deleteRoute(SavedRoute route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المسار'),
        content: Text('هل تريد حذف مسار "${route.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.instance.deleteRoute(route.id!);
      await _loadRoutes();
    }
  }

  Future<void> _renameRoute(SavedRoute route) async {
    final controller = TextEditingController(text: route.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعادة تسمية المسار'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم المسار', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await DatabaseService.instance.updateRoute(route.copyWith(name: newName));
      await _loadRoutes();
    }
  }

  void _useRoute(SavedRoute route) async {
    await DatabaseService.instance.incrementRouteUsage(route.id!);
    if (widget.onRouteSelected != null) {
      widget.onRouteSelected!(route);
      Navigator.pop(context);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RoutePreviewScreen(route: route)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المسارات المحفوظة'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.route), text: 'جميع المسارات'),
            Tab(icon: Icon(Icons.favorite), text: 'المفضلة'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // شريط البحث
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'ابحث عن مسار...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRouteList(_filteredRoutes, theme),
                      _buildRouteList(_favoriteRoutes, theme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRouteList(List<SavedRoute> routes, ThemeData theme) {
    if (routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('لا توجد مسارات محفوظة',
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('احفظ مساراتك بعد انتهاء جلسة المشي',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: routes.length,
      itemBuilder: (_, i) => _buildRouteCard(routes[i], theme),
    );
  }

  Widget _buildRouteCard(SavedRoute route, ThemeData theme) {
    final color = _colorFromString(route.thumbnailColor);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // شريط ملون علوي بدل الصورة
          Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.4)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // أيقونة الصعوبة
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.15),
                  ),
                  child: Center(
                    child: Text(route.difficultyEmoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                // المعلومات
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(route.name,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                          if (route.isFavorite)
                            const Icon(Icons.favorite, color: Colors.red, size: 16),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(route.description,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _chip(Icons.straighten, route.distanceFormatted, theme),
                          const SizedBox(width: 8),
                          _chip(Icons.flag, route.difficultyLabel, theme),
                          if (route.elevationGainMeters != null) ...[
                            const SizedBox(width: 8),
                            _chip(Icons.terrain, '↑${route.elevationGainMeters!.toStringAsFixed(0)}م', theme),
                          ],
                          const Spacer(),
                          if (route.usageCount > 0)
                            Text('${route.usageCount}× استخدام',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                // أزرار
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'use': _useRoute(route); break;
                      case 'preview':
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => RoutePreviewScreen(route: route)));
                        break;
                      case 'favorite':
                        await DatabaseService.instance.toggleFavorite(route.id!, route.isFavorite);
                        await _loadRoutes();
                        break;
                      case 'rename': await _renameRoute(route); break;
                      case 'delete': await _deleteRoute(route); break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'use',
                        child: Row(children: [Icon(Icons.play_arrow, color: Colors.green), SizedBox(width: 8), Text('استخدم هذا المسار')])),
                    const PopupMenuItem(value: 'preview',
                        child: Row(children: [Icon(Icons.map), SizedBox(width: 8), Text('معاينة الخريطة')])),
                    PopupMenuItem(value: 'favorite',
                        child: Row(children: [
                          Icon(route.isFavorite ? Icons.favorite_border : Icons.favorite, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(route.isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة'),
                        ])),
                    const PopupMenuItem(value: 'rename',
                        child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('إعادة تسمية')])),
                    const PopupMenuItem(value: 'delete',
                        child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('حذف', style: TextStyle(color: Colors.red))])),
                  ],
                ),
              ],
            ),
          ),
          // زر الاستخدام السريع
          if (widget.onRouteSelected != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: FilledButton.icon(
                onPressed: () => _useRoute(route),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('ابدأ هذا المسار'),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Color _colorFromString(String? s) {
    if (s == null) return Colors.teal;
    final colors = [Colors.teal, Colors.blue, Colors.orange, Colors.purple, Colors.green, Colors.indigo];
    return colors[s.hashCode.abs() % colors.length];
  }
}