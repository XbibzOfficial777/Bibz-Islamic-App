part of '../main.dart';

const apiBaseUrl = 'https://bibzislamicc.vercel.app/api/v1';

class SurahSummary {
  const SurahSummary({
    required this.number,
    required this.name,
    required this.ayahCount,
  });
  final int number;
  final String name;
  final int ayahCount;
}

class Ayah {
  const Ayah({
    required this.number,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    this.juz,
    this.audioUrl,
  });
  final int number;
  final String arabic;
  final String transliteration;
  final String translation;
  final int? juz;
  final String? audioUrl;

  factory Ayah.fromJson(Map<String, dynamic> json) => Ayah(
    number: json['ayahNumber'] as int,
    arabic: json['arabicText'] as String,
    transliteration: (json['latinText'] as String?) ?? '',
    translation: (json['indonesianTranslation'] as String?) ?? '',
    juz: json['juz'] as int?,
    audioUrl: json['audioMp3Url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'ayahNumber': number,
    'arabicText': arabic,
    'latinText': transliteration,
    'indonesianTranslation': translation,
    'juz': juz,
    'audioMp3Url': audioUrl,
  };
}

class Surah {
  const Surah({
    required this.number,
    required this.nameArabic,
    required this.nameLatin,
    required this.meaning,
    required this.revelationType,
    required this.description,
    required this.ayahs,
    this.fullAudioUrl,
  });
  final int number;
  final String nameArabic;
  final String nameLatin;
  final String meaning;
  final String revelationType;
  final String description;
  final List<Ayah> ayahs;
  final String? fullAudioUrl;

  factory Surah.fromJson(Map<String, dynamic> json) {
    final details = Map<String, dynamic>.from(json['surahDetails'] as Map);
    final rawAyahs = json['ayahs'] as List;
    final ayahs = rawAyahs
        .map((item) => Ayah.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    final number = details['number'] as int;
    final expected = details['numberOfAyahs'] as int;
    QuranValidator.validate(number, expected, ayahs);
    return Surah(
      number: number,
      nameArabic: details['nameArabic'] as String,
      nameLatin: details['nameLatin'] as String,
      meaning: details['translationMeaning'] as String,
      revelationType: details['revelationType'] as String,
      description: _stripHtml(details['description'] as String? ?? ''),
      ayahs: ayahs,
      fullAudioUrl: details['audioFullSurahMp3'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'surahDetails': {
      'number': number,
      'nameArabic': nameArabic,
      'nameLatin': nameLatin,
      'translationMeaning': meaning,
      'revelationType': revelationType,
      'description': description,
      'numberOfAyahs': ayahs.length,
      'audioFullSurahMp3': fullAudioUrl,
    },
    'ayahs': ayahs.map((ayah) => ayah.toJson()).toList(),
  };
}

String _stripHtml(String value) => value
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class QuranValidator {
  static void validate(int surahNumber, int expectedCount, List<Ayah> ayahs) {
    if (surahNumber < 1 || surahNumber > 114) {
      throw const FormatException('Nomor surah tidak valid');
    }
    if (ayahs.length != expectedCount) {
      throw const FormatException('Jumlah ayah tidak sesuai metadata');
    }
    for (var index = 0; index < ayahs.length; index++) {
      final ayah = ayahs[index];
      if (ayah.number != index + 1) {
        throw const FormatException('Urutan ayah tidak valid');
      }
      if (ayah.arabic.trim().isEmpty || ayah.translation.trim().isEmpty) {
        throw const FormatException('Teks ayah wajib tersedia');
      }
    }
  }
}

class QuranApiClient {
  QuranApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Surah> fetchSurah(int number) async {
    final response = await _client
        .get(Uri.parse('$apiBaseUrl/quran/surah?surah=$number'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException('Server mengembalikan HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw ApiException(body['message'] as String? ?? 'Data tidak tersedia');
    }
    return Surah.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    final encoded = Uri.encodeQueryComponent(query.trim());
    final response = await _client
        .get(Uri.parse('$apiBaseUrl/quran/search?q=$encoded'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException('Server mengembalikan HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw ApiException(body['message'] as String? ?? 'Pencarian gagal');
    }
    final data = Map<String, dynamic>.from(body['data'] as Map);
    return (data['results'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum AppThemePreference { system, light, dark }

class LocalStore {
  LocalStore(this.preferences);
  final SharedPreferences preferences;

  Future<void> saveSurah(Surah surah) async {
    await preferences.setString(
      'surah_${surah.number}',
      jsonEncode(surah.toJson()),
    );
  }

  Surah? readSurah(int number) {
    final raw = preferences.getString('surah_$number');
    if (raw == null) return null;
    try {
      return Surah.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      preferences.remove('surah_$number');
      return null;
    }
  }

  Future<void> deleteSurah(int number) async {
    await preferences.remove('surah_$number');
  }

  Set<String> bookmarks() =>
      preferences.getStringList('bookmarks')?.toSet() ?? <String>{};

  Future<void> setBookmarks(Set<String> values) async {
    await preferences.setStringList('bookmarks', values.toList());
  }

  Map<String, dynamic>? lastRead() {
    final raw = preferences.getString('last_read');
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveLastRead(int surah, int ayah) async {
    await preferences.setString(
      'last_read',
      jsonEncode({'surah': surah, 'ayah': ayah}),
    );
  }

  AppThemePreference themePreference() {
    switch (preferences.getString('theme_preference')) {
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      default:
        return AppThemePreference.system;
    }
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    await preferences.setString('theme_preference', preference.name);
  }
}

class QuranRepository {
  QuranRepository(this.api, this.store);
  final QuranApiClient api;
  final LocalStore store;

  Future<Surah> getSurah(int number) async {
    final local = store.readSurah(number);
    if (local != null) return local;
    final remote = await api.fetchSurah(number);
    await store.saveSurah(remote);
    return remote;
  }

  List<Map<String, dynamic>> searchLocal(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    final results = <Map<String, dynamic>>[];
    for (final summary in surahCatalog) {
      final surah = store.readSurah(summary.number);
      if (surah == null) continue;
      for (final ayah in surah.ayahs) {
        final haystack =
            '${ayah.arabic} ${ayah.transliteration} ${ayah.translation}'
                .toLowerCase();
        if (haystack.contains(normalized)) {
          results.add({
            'surahNumber': surah.number,
            'ayahNumber': ayah.number,
            'arabicText': ayah.arabic,
            'translationId': ayah.translation,
          });
        }
      }
    }
    return results;
  }

  List<Map<String, dynamic>> searchSurah(String query) {
    final normalized = query.trim().toLowerCase();
    return surahCatalog
        .where(
          (summary) =>
              summary.number.toString() == normalized ||
              summary.name.toLowerCase().contains(normalized),
        )
        .map(
          (summary) => {
            'title': '${summary.number}. ${summary.name}',
            'subtitle': '${summary.ayahCount} ayat',
            'surahNumber': summary.number,
            'ayahNumber': 1,
          },
        )
        .toList();
  }

  List<Map<String, dynamic>> searchJuz(int juz) {
    final results = <Map<String, dynamic>>[];
    for (final summary in surahCatalog) {
      final surah = store.readSurah(summary.number);
      if (surah == null) continue;
      for (final ayah in surah.ayahs) {
        final inCanonicalRange =
            juz >= 1 &&
            juz <= canonicalJuzRanges.length &&
            _inJuzRange(surah.number, ayah.number, canonicalJuzRanges[juz - 1]);
        if (ayah.juz == juz || inCanonicalRange) {
          results.add({
            'title': 'QS. ${surah.number}:${ayah.number}',
            'subtitle': ayah.translation,
            'surahNumber': surah.number,
            'ayahNumber': ayah.number,
          });
        }
      }
    }
    return results;
  }
}

const surahCatalog = <SurahSummary>[
  SurahSummary(number: 1, name: 'Al-Fatihah', ayahCount: 7),
  SurahSummary(number: 2, name: 'Al-Baqarah', ayahCount: 286),
  SurahSummary(number: 3, name: 'Ali Imran', ayahCount: 200),
  SurahSummary(number: 4, name: 'An-Nisa', ayahCount: 176),
  SurahSummary(number: 5, name: 'Al-Maidah', ayahCount: 120),
  SurahSummary(number: 6, name: 'Al-Anam', ayahCount: 165),
  SurahSummary(number: 7, name: 'Al-Araf', ayahCount: 206),
  SurahSummary(number: 8, name: 'Al-Anfal', ayahCount: 75),
  SurahSummary(number: 9, name: 'At-Taubah', ayahCount: 129),
  SurahSummary(number: 10, name: 'Yunus', ayahCount: 109),
  SurahSummary(number: 11, name: 'Hud', ayahCount: 123),
  SurahSummary(number: 12, name: 'Yusuf', ayahCount: 111),
  SurahSummary(number: 13, name: 'Ar-Rad', ayahCount: 43),
  SurahSummary(number: 14, name: 'Ibrahim', ayahCount: 52),
  SurahSummary(number: 15, name: 'Al-Hijr', ayahCount: 99),
  SurahSummary(number: 16, name: 'An-Nahl', ayahCount: 128),
  SurahSummary(number: 17, name: 'Al-Isra', ayahCount: 111),
  SurahSummary(number: 18, name: 'Al-Kahf', ayahCount: 110),
  SurahSummary(number: 19, name: 'Maryam', ayahCount: 98),
  SurahSummary(number: 20, name: 'Taha', ayahCount: 135),
  SurahSummary(number: 21, name: 'Al-Anbiya', ayahCount: 112),
  SurahSummary(number: 22, name: 'Al-Hajj', ayahCount: 78),
  SurahSummary(number: 23, name: 'Al-Muminun', ayahCount: 118),
  SurahSummary(number: 24, name: 'An-Nur', ayahCount: 64),
  SurahSummary(number: 25, name: 'Al-Furqan', ayahCount: 77),
  SurahSummary(number: 26, name: 'Ash-Shuara', ayahCount: 227),
  SurahSummary(number: 27, name: 'An-Naml', ayahCount: 93),
  SurahSummary(number: 28, name: 'Al-Qasas', ayahCount: 88),
  SurahSummary(number: 29, name: 'Al-Ankabut', ayahCount: 69),
  SurahSummary(number: 30, name: 'Ar-Rum', ayahCount: 60),
  SurahSummary(number: 31, name: 'Luqman', ayahCount: 34),
  SurahSummary(number: 32, name: 'As-Sajdah', ayahCount: 30),
  SurahSummary(number: 33, name: 'Al-Ahzab', ayahCount: 73),
  SurahSummary(number: 34, name: 'Saba', ayahCount: 54),
  SurahSummary(number: 35, name: 'Fatir', ayahCount: 45),
  SurahSummary(number: 36, name: 'Yasin', ayahCount: 83),
  SurahSummary(number: 37, name: 'As-Saffat', ayahCount: 182),
  SurahSummary(number: 38, name: 'Sad', ayahCount: 88),
  SurahSummary(number: 39, name: 'Az-Zumar', ayahCount: 75),
  SurahSummary(number: 40, name: 'Ghafir', ayahCount: 85),
  SurahSummary(number: 41, name: 'Fussilat', ayahCount: 54),
  SurahSummary(number: 42, name: 'Ash-Shura', ayahCount: 53),
  SurahSummary(number: 43, name: 'Az-Zukhruf', ayahCount: 89),
  SurahSummary(number: 44, name: 'Ad-Dukhan', ayahCount: 59),
  SurahSummary(number: 45, name: 'Al-Jathiyah', ayahCount: 37),
  SurahSummary(number: 46, name: 'Al-Ahqaf', ayahCount: 35),
  SurahSummary(number: 47, name: 'Muhammad', ayahCount: 38),
  SurahSummary(number: 48, name: 'Al-Fath', ayahCount: 29),
  SurahSummary(number: 49, name: 'Al-Hujurat', ayahCount: 18),
  SurahSummary(number: 50, name: 'Qaf', ayahCount: 45),
  SurahSummary(number: 51, name: 'Adh-Dhariyat', ayahCount: 60),
  SurahSummary(number: 52, name: 'At-Tur', ayahCount: 49),
  SurahSummary(number: 53, name: 'An-Najm', ayahCount: 62),
  SurahSummary(number: 54, name: 'Al-Qamar', ayahCount: 55),
  SurahSummary(number: 55, name: 'Ar-Rahman', ayahCount: 78),
  SurahSummary(number: 56, name: 'Al-Waqiah', ayahCount: 96),
  SurahSummary(number: 57, name: 'Al-Hadid', ayahCount: 29),
  SurahSummary(number: 58, name: 'Al-Mujadilah', ayahCount: 22),
  SurahSummary(number: 59, name: 'Al-Hashr', ayahCount: 24),
  SurahSummary(number: 60, name: 'Al-Mumtahanah', ayahCount: 13),
  SurahSummary(number: 61, name: 'As-Saff', ayahCount: 14),
  SurahSummary(number: 62, name: 'Al-Jumuah', ayahCount: 11),
  SurahSummary(number: 63, name: 'Al-Munafiqun', ayahCount: 11),
  SurahSummary(number: 64, name: 'At-Taghabun', ayahCount: 18),
  SurahSummary(number: 65, name: 'At-Talaq', ayahCount: 12),
  SurahSummary(number: 66, name: 'At-Tahrim', ayahCount: 12),
  SurahSummary(number: 67, name: 'Al-Mulk', ayahCount: 30),
  SurahSummary(number: 68, name: 'Al-Qalam', ayahCount: 52),
  SurahSummary(number: 69, name: 'Al-Haqqah', ayahCount: 52),
  SurahSummary(number: 70, name: 'Al-Maarij', ayahCount: 44),
  SurahSummary(number: 71, name: 'Nuh', ayahCount: 28),
  SurahSummary(number: 72, name: 'Al-Jinn', ayahCount: 28),
  SurahSummary(number: 73, name: 'Al-Muzzammil', ayahCount: 20),
  SurahSummary(number: 74, name: 'Al-Muddaththir', ayahCount: 56),
  SurahSummary(number: 75, name: 'Al-Qiyamah', ayahCount: 40),
  SurahSummary(number: 76, name: 'Al-Insan', ayahCount: 31),
  SurahSummary(number: 77, name: 'Al-Mursalat', ayahCount: 50),
  SurahSummary(number: 78, name: 'An-Naba', ayahCount: 40),
  SurahSummary(number: 79, name: 'An-Naziat', ayahCount: 46),
  SurahSummary(number: 80, name: 'Abasa', ayahCount: 42),
  SurahSummary(number: 81, name: 'At-Takwir', ayahCount: 29),
  SurahSummary(number: 82, name: 'Al-Infitar', ayahCount: 19),
  SurahSummary(number: 83, name: 'Al-Mutaffifin', ayahCount: 36),
  SurahSummary(number: 84, name: 'Al-Inshiqaq', ayahCount: 25),
  SurahSummary(number: 85, name: 'Al-Buruj', ayahCount: 22),
  SurahSummary(number: 86, name: 'At-Tariq', ayahCount: 17),
  SurahSummary(number: 87, name: 'Al-Ala', ayahCount: 19),
  SurahSummary(number: 88, name: 'Al-Ghashiyah', ayahCount: 26),
  SurahSummary(number: 89, name: 'Al-Fajr', ayahCount: 30),
  SurahSummary(number: 90, name: 'Al-Balad', ayahCount: 20),
  SurahSummary(number: 91, name: 'Ash-Shams', ayahCount: 15),
  SurahSummary(number: 92, name: 'Al-Lail', ayahCount: 21),
  SurahSummary(number: 93, name: 'Ad-Duha', ayahCount: 11),
  SurahSummary(number: 94, name: 'Ash-Sharh', ayahCount: 8),
  SurahSummary(number: 95, name: 'At-Tin', ayahCount: 8),
  SurahSummary(number: 96, name: 'Al-Alaq', ayahCount: 19),
  SurahSummary(number: 97, name: 'Al-Qadr', ayahCount: 5),
  SurahSummary(number: 98, name: 'Al-Bayyinah', ayahCount: 8),
  SurahSummary(number: 99, name: 'Az-Zalzalah', ayahCount: 8),
  SurahSummary(number: 100, name: 'Al-Adiyat', ayahCount: 11),
  SurahSummary(number: 101, name: 'Al-Qariah', ayahCount: 11),
  SurahSummary(number: 102, name: 'At-Takathur', ayahCount: 8),
  SurahSummary(number: 103, name: 'Al-Asr', ayahCount: 3),
  SurahSummary(number: 104, name: 'Al-Humazah', ayahCount: 9),
  SurahSummary(number: 105, name: 'Al-Fil', ayahCount: 5),
  SurahSummary(number: 106, name: 'Quraisy', ayahCount: 4),
  SurahSummary(number: 107, name: 'Al-Maun', ayahCount: 7),
  SurahSummary(number: 108, name: 'Al-Kausar', ayahCount: 3),
  SurahSummary(number: 109, name: 'Al-Kafirun', ayahCount: 6),
  SurahSummary(number: 110, name: 'An-Nasr', ayahCount: 3),
  SurahSummary(number: 111, name: 'Al-Masad', ayahCount: 5),
  SurahSummary(number: 112, name: 'Al-Ikhlas', ayahCount: 4),
  SurahSummary(number: 113, name: 'Al-Falaq', ayahCount: 5),
  SurahSummary(number: 114, name: 'An-Nas', ayahCount: 6),
];
