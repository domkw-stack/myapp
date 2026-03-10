import 'package:flutter/material.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import '../services/radio_browser_service.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});
  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen>
    with SingleTickerProviderStateMixin {
  final _radio = RadioService.instance;
  final _browser = RadioBrowserService.instance;

  late TabController _tabController;
  RadioState _state = RadioState.stopped;
  RadioStation? _currentStation;
  double _volume = 0.8;

  // بحث
  final _searchCtrl = TextEditingController();
  List<RadioStation> _searchResults = [];
  bool _searching = false;

  // محطات مكتشفة
  List<RadioStation> _topStations = [];
  bool _loadingTop = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _radio.init();
    _state = _radio.state;
    _currentStation = _radio.currentStation;
    _volume = _radio.volume;

    _radio.onStateChanged  = (s) { if (mounted) setState(() => _state = s); };
    _radio.onStationChanged = (s) { if (mounted) setState(() => _currentStation = s); };
    _radio.onError = (msg) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
    };

    // تحميل الأكثر شهرة فور فتح الشاشة
    _loadTopStations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTopStations() async {
    setState(() => _loadingTop = true);
    final r = await _browser.topStations(limit: 20);
    if (mounted) setState(() { _topStations = r; _loadingTop = false; });
  }

  Future<void> _doSearch(String q) async {
    if (q.trim().isEmpty) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    final r = await _browser.search(q.trim());
    if (mounted) setState(() { _searchResults = r; _searching = false; });
  }

  // ─── بناء الشاشة ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('راديو المشي 📻'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.flag),       text: 'سوري 🇸🇾'),
            Tab(icon: Icon(Icons.language),   text: 'عربي'),
            Tab(icon: Icon(Icons.public),     text: 'الأشهر'),
            Tab(icon: Icon(Icons.search),     text: 'بحث'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPlayerCard(theme),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStationList(RadioStations.syrian, theme),
                _buildStationList(RadioStations.arabic, theme),
                _buildTopTab(theme),
                _buildSearchTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── مشغل ثابت ──────────────────────────────────────────────────────────
  Widget _buildPlayerCard(ThemeData theme) {
    final isPlaying = _state == RadioState.playing;
    final isLoading = _state == RadioState.loading;
    final color = _stationColor(_currentStation);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 16, offset: const Offset(0,4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // أيقونة
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: Center(child: Text(_currentStation?.flag ?? '📻',
                    style: const TextStyle(fontSize: 30))),
              ),
              const SizedBox(width: 12),

              // المعلومات
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentStation?.name ?? 'اختر محطة',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (isPlaying)  _pulsingDot()
                      else if (isLoading) const SizedBox(width: 10, height: 10,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 6),
                      Text(
                        isPlaying ? '🔴 يبث الآن' : isLoading ? 'جارٍ التحميل...' :
                        _currentStation != null ? 'متوقف' : 'اختر محطة',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                      ),
                    ]),
                    if (_currentStation?.genre.isNotEmpty == true)
                      Text(_currentStation!.genre,
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                  ],
                ),
              ),

              // زر تشغيل
              GestureDetector(
                onTap: () {
                  if (isPlaying) _radio.stop();
                  else if (_currentStation != null) _radio.play(_currentStation!);
                },
                child: Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                  ),
                  child: isLoading
                    ? Padding(padding: const EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 3, color: color))
                    : Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        color: color, size: 30),
                ),
              ),
            ],
          ),

          // شريط صوت
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.volume_mute, color: Colors.white70, size: 18),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                  thumbColor: Colors.white,
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: _volume,
                  onChanged: (v) { setState(() => _volume = v); _radio.setVolume(v); },
                ),
              ),
            ),
            const Icon(Icons.volume_up, color: Colors.white70, size: 18),
          ]),
        ],
      ),
    );
  }

  // ─── قوائم المحطات ───────────────────────────────────────────────────────
  Widget _buildStationList(List<RadioStation> stations, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: stations.length,
      itemBuilder: (_, i) => _stationTile(stations[i], theme),
    );
  }

  // ─── تبويب الأشهر ────────────────────────────────────────────────────────
  Widget _buildTopTab(ThemeData theme) {
    if (_loadingTop) return const Center(child: CircularProgressIndicator());
    if (_topStations.isEmpty) return Center(
      child: TextButton.icon(
        onPressed: _loadTopStations,
        icon: const Icon(Icons.refresh),
        label: const Text('تحميل الأشهر عالمياً'),
      ),
    );
    return RefreshIndicator(
      onRefresh: _loadTopStations,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: _topStations.length,
        itemBuilder: (_, i) => _stationTile(_topStations[i], theme),
      ),
    );
  }

  // ─── تبويب البحث ─────────────────────────────────────────────────────────
  Widget _buildSearchTab(ThemeData theme) {
    return Column(
      children: [
        // حقل البحث
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ابحث عن أي محطة في العالم...',
              prefixIcon: _searching
                  ? const Padding(padding: EdgeInsets.all(12),
                      child: SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                  : const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _doSearch,
            onChanged: (v) {
              setState(() {});
              if (v.length >= 3) _doSearch(v);
            },
          ),
        ),

        // اختصارات بحث سريع
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _quickSearchChip('🇸🇾 سوريا', 'syria'),
              _quickSearchChip('🎵 Lo-Fi', 'lofi'),
              _quickSearchChip('🕌 قرآن', 'quran'),
              _quickSearchChip('📰 أخبار', 'news arabic'),
              _quickSearchChip('🎷 Jazz', 'jazz'),
              _quickSearchChip('🌍 BBC', 'bbc'),
              _quickSearchChip('🎸 Rock', 'rock'),
            ],
          ),
        ),

        // نتائج البحث
        Expanded(
          child: _searchResults.isEmpty && !_searching
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🔍', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text('ابحث في 30,000+ محطة',
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 4),
                      const Text('اكتب اسم المحطة أو البلد أو النوع',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _searchResults.length,
                  itemBuilder: (_, i) => _stationTile(_searchResults[i], theme),
                ),
        ),
      ],
    );
  }

  Widget _quickSearchChip(String label, String query) {
    return GestureDetector(
      onTap: () {
        _searchCtrl.text = query;
        _doSearch(query);
        _tabController.animateTo(3);
      },
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  // ─── بطاقة محطة ──────────────────────────────────────────────────────────
  Widget _stationTile(RadioStation station, ThemeData theme) {
    final isSelected = _currentStation?.id == station.id;
    final isPlaying  = isSelected && _state == RadioState.playing;
    final isLoading  = isSelected && _state == RadioState.loading;
    final color = _stationColor(station);
    final isFav = _radio.isFavorite(station);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isSelected
            ? color.withOpacity(0.12)
            : theme.colorScheme.surfaceVariant.withOpacity(0.5),
        border: Border.all(
          color: isSelected ? color : Colors.transparent,
          width: isSelected ? 2 : 0,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 12)] : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Stack(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.5)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Center(child: Text(station.flag, style: const TextStyle(fontSize: 22))),
            ),
            if (isPlaying)
              Positioned(right: 0, bottom: 0,
                child: Container(width: 16, height: 16,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                  child: const Icon(Icons.graphic_eq, color: Colors.white, size: 11))),
          ],
        ),
        title: Text(station.name, style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? color : null,
        )),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (station.genre.isNotEmpty)
              Text(station.genre, style: const TextStyle(fontSize: 12)),
            if (station.description != null)
              Text(station.description!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.red : Colors.grey, size: 20),
              onPressed: () => setState(() => _radio.toggleFavorite(station)),
            ),
            isLoading
              ? const SizedBox(width: 36, height: 36,
                  child: Padding(padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: Icon(
                    isPlaying ? Icons.stop_circle : Icons.play_circle_filled,
                    color: isPlaying ? Colors.red : color, size: 36,
                  ),
                  onPressed: () => isPlaying ? _radio.stop() : _radio.play(station),
                ),
          ],
        ),
        onTap: () => isPlaying ? _radio.stop() : _radio.play(station),
      ),
    );
  }

  Widget _pulsingDot() => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.4, end: 1.0),
    duration: const Duration(milliseconds: 600),
    builder: (_, v, __) => Opacity(
      opacity: v,
      child: Container(width: 8, height: 8,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent)),
    ),
  );

  Color _stationColor(RadioStation? s) {
    if (s == null) return const Color(0xFF2ECC71);
    switch (s.id) {
      case 'sy_orient':        return const Color(0xFF1565C0);
      case 'sy_rotana_sham':   return const Color(0xFFAD1457);
      case 'sy_fm_damascus':   return const Color(0xFF00695C);
      case 'sy_sham_fm':       return const Color(0xFF4527A0);
      case 'sy_art_music':     return const Color(0xFFC62828);
      case 'ar_quran':         return const Color(0xFF1B5E20);
      case 'int_lofi':         return const Color(0xFF4A148C);
      default:
        // لون عشوائي ثابت من ID
        final h = s.id.hashCode.abs() % 360;
        return HSLColor.fromAHSL(1, h.toDouble(), 0.6, 0.4).toColor();
    }
  }
}
