class RadioStation {
  final String id;
  final String name;
  final String nameEn;
  final String streamUrl;
  final String country;
  final String flag;
  final String genre;
  final String? description;
  final String? logoAsset;
  final bool isCustom; // محطة أضافها المستخدم يدوياً

  const RadioStation({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.streamUrl,
    required this.country,
    required this.flag,
    required this.genre,
    this.description,
    this.logoAsset,
    this.isCustom = false,
  });

  RadioStation copyWith({String? name, String? streamUrl}) => RadioStation(
    id: id, nameEn: nameEn, country: country, flag: flag,
    genre: genre, description: description, logoAsset: logoAsset,
    isCustom: isCustom,
    name: name ?? this.name,
    streamUrl: streamUrl ?? this.streamUrl,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'nameEn': nameEn, 'streamUrl': streamUrl,
    'country': country, 'flag': flag, 'genre': genre,
    'description': description, 'isCustom': isCustom,
  };

  factory RadioStation.fromJson(Map<String, dynamic> j) => RadioStation(
    id: j['id'], name: j['name'], nameEn: j['nameEn'] ?? j['name'],
    streamUrl: j['streamUrl'], country: j['country'] ?? 'دولي',
    flag: j['flag'] ?? '🌍', genre: j['genre'] ?? 'متنوع',
    description: j['description'], isCustom: j['isCustom'] ?? false,
  );
}

// ─── المحطات المدمجة ──────────────────────────────────────────────────────────
class RadioStations {
  static const List<RadioStation> all = [

    // ══════════════ السورية 🇸🇾 ══════════════
    RadioStation(id: 'sy_orient',     name: 'راديو أورينت',      nameEn: 'Radio Orient',
      streamUrl: 'https://listen.radioking.com/radio/285543/stream/329737',
      country: 'سوريا', flag: '🇸🇾', genre: 'أغاني وأخبار',
      description: 'موسيقى عربية وأخبار سورية'),
    RadioStation(id: 'sy_rotana_sham',name: 'روتانا شام',         nameEn: 'Rotana Sham',
      streamUrl: 'https://stream.zeno.fm/yn65m9yq7xhvv',
      country: 'سوريا', flag: '🇸🇾', genre: 'أغاني سورية',
      description: 'الموسيقى السورية والعربية'),
    RadioStation(id: 'sy_fm_damascus',name: 'دمشق FM',            nameEn: 'Damascus FM',
      streamUrl: 'https://stream.zeno.fm/x4zmetflz8zuv',
      country: 'سوريا', flag: '🇸🇾', genre: 'متنوع',
      description: 'محطة دمشق الإذاعية'),
    RadioStation(id: 'sy_sham_fm',    name: 'شام FM',              nameEn: 'Sham FM',
      streamUrl: 'https://stream.zeno.fm/4d1s601tafsv',
      country: 'سوريا', flag: '🇸🇾', genre: 'أغاني وترفيه',
      description: 'من دمشق، موسيقى وترفيه'),
    RadioStation(id: 'sy_art_music',  name: 'طرب سوري',           nameEn: 'Syrian Tarab',
      streamUrl: 'https://stream.zeno.fm/0r0xa792kwzuv',
      country: 'سوريا', flag: '🇸🇾', genre: 'طرب أصيل',
      description: 'كلاسيكيات سورية وطرب أصيل'),
    RadioStation(id: 'sy_ninar',      name: 'إذاعة نينار FM',     nameEn: 'Ninar FM',
      streamUrl: 'https://stream.zeno.fm/hbptd03h0mhvv',
      country: 'سوريا', flag: '🇸🇾', genre: 'متنوع',
      description: 'إذاعة سورية رسمية'),

    // ══════════════ عربي ══════════════
    RadioStation(id: 'ar_quran',      name: 'القرآن الكريم',      nameEn: 'Holy Quran',
      streamUrl: 'https://stream.radiojar.com/quran',
      country: 'عربي', flag: '🕌', genre: 'قرآن كريم',
      description: 'القرآن الكريم على مدار الساعة'),
    RadioStation(id: 'ar_monte_carlo',name: 'مونت كارلو الدولية', nameEn: 'MCD',
      streamUrl: 'https://stream.rfi.fr/mcd-128.mp3',
      country: 'دولي', flag: '🌍', genre: 'أخبار',
      description: 'أخبار وثقافة بالعربية'),
    RadioStation(id: 'ar_bbc',        name: 'BBC عربي',           nameEn: 'BBC Arabic',
      streamUrl: 'https://bbcwsrd.akamaized.net/hls/live/2030966/bbcarabic/bbcarabic_512k.m3u8',
      country: 'دولي', flag: '🌍', genre: 'أخبار',
      description: 'BBC بالعربية'),
    RadioStation(id: 'ar_rotana_k',   name: 'روتانا خليجية',      nameEn: 'Rotana Khalijiah',
      streamUrl: 'https://stream.zeno.fm/4d1s601tafsv',
      country: 'خليجي', flag: '🌍', genre: 'خليجي',
      description: 'أفضل أغاني الخليج'),
    RadioStation(id: 'ar_nogoum',     name: 'نجوم FM',             nameEn: 'Nogoum FM',
      streamUrl: 'https://stream.zeno.fm/b4mv53snqhzuv',
      country: 'مصر', flag: '🇪🇬', genre: 'عربي متنوع',
      description: 'نجوم FM مصر'),
    RadioStation(id: 'ar_voiceoflebanon', name: 'صوت لبنان',      nameEn: 'Voice of Lebanon',
      streamUrl: 'https://stream.zeno.fm/yfhmdktqlwzuv',
      country: 'لبنان', flag: '🇱🇧', genre: 'متنوع',
      description: 'صوت لبنان الإذاعي'),

    // ══════════════ عالمي 🎵 ══════════════
    RadioStation(id: 'int_lofi',      name: 'Lo-Fi Chill',         nameEn: 'Lo-Fi Chill',
      streamUrl: 'https://stream.zeno.fm/f3wvbbqmdg8uv',
      country: 'دولي', flag: '🎵', genre: 'Lo-Fi',
      description: 'موسيقى هادئة للمشي'),
    RadioStation(id: 'int_jazz',      name: 'Jazz 24',              nameEn: 'Jazz 24',
      streamUrl: 'https://live.wostreaming.net/manifests/ppm-jazz24aac256-ibc1.m3u8',
      country: 'دولي', flag: '🎷', genre: 'جاز'),
    RadioStation(id: 'int_classical', name: 'كلاسيكية',            nameEn: 'Classical Radio',
      streamUrl: 'https://stream.srg-ssr.ch/rsc_de/mp3_128.m3u',
      country: 'دولي', flag: '🎻', genre: 'كلاسيك'),
    RadioStation(id: 'int_nature',    name: 'أصوات الطبيعة',       nameEn: 'Nature Sounds',
      streamUrl: 'https://stream.zeno.fm/yn65m9yq7xhvv',
      country: 'دولي', flag: '🌿', genre: 'طبيعة',
      description: 'أصوات طبيعة مريحة'),
  ];

  static List<RadioStation> get syrian =>
      all.where((s) => s.country == 'سوريا').toList();
  static List<RadioStation> get arabic =>
      all.where((s) => !_isIntl(s)).toList();
  static List<RadioStation> get international =>
      all.where((s) => _isIntl(s)).toList();

  static bool _isIntl(RadioStation s) =>
      ['🎵','🎷','🎻','🌿'].contains(s.flag);
}
