import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

part 'production_features.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DiagnosticLog.record(
      details.exception,
      details.stack ?? StackTrace.current,
      context: 'flutter.framework',
    );
  };
  final preferences = await SharedPreferences.getInstance();
  await DiagnosticLog.initialize(preferences);
  runZonedGuarded(
    () => runApp(
      BibzApp(
        repository: QuranRepository(QuranApiClient(), LocalStore(preferences)),
      ),
    ),
    (error, stack) => DiagnosticLog.record(error, stack, context: 'dart.zone'),
  );
}

class BibzApp extends StatefulWidget {
  const BibzApp({super.key, required this.repository});
  final QuranRepository repository;

  @override
  State<BibzApp> createState() => _BibzAppState();
}

class _BibzAppState extends State<BibzApp> {
  late QuranXAppearance appearance;
  late final AudioController audio;
  late final NetworkMonitor network;

  @override
  void initState() {
    super.initState();
    appearance = widget.repository.store.appearance();
    audio = AudioController();
    network = NetworkMonitor();
  }

  @override
  void dispose() {
    audio.dispose();
    network.dispose();
    super.dispose();
  }

  Future<void> setAppearance(QuranXAppearance value) async {
    await widget.repository.store.saveAppearance(value);
    if (mounted) setState(() => appearance = value);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QuranX',
    debugShowCheckedModeBanner: false,
    themeMode: appearance.themeMode,
    theme: ThemeData(
      fontFamily: appearance.resolvedFontFamily,
      colorScheme: ColorScheme.fromSeed(seedColor: appearance.seedColor),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      fontFamily: appearance.resolvedFontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: appearance.seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(appearance.textScale)),
      child: child ?? const SizedBox.shrink(),
    ),
    home: HomeScreen(
      repository: widget.repository,
      appearance: appearance,
      onAppearanceChanged: setAppearance,
      audio: audio,
      network: network,
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.appearance,
    required this.onAppearanceChanged,
    required this.audio,
    required this.network,
  });
  final QuranRepository repository;
  final QuranXAppearance appearance;
  final Future<void> Function(QuranXAppearance) onAppearanceChanged;
  final AudioController audio;
  final NetworkMonitor network;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  final searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool searching = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> runSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => searchResults = []);
      return;
    }
    setState(() => searching = true);
    try {
      final local = widget.repository.searchLocal(query);
      final results = local.isNotEmpty
          ? local
          : await widget.repository.api.search(query);
      if (mounted) setState(() => searchResults = results);
    } catch (error, stack) {
      final detail = DiagnosticLog.record(error, stack, context: 'home.search');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Pencarian tidak tersedia. Detail tersimpan di Log kesalahan.',
            ),
            action: SnackBarAction(
              label: 'Lihat',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
              ),
            ),
          ),
        );
        developer.log(detail, name: 'QuranX.search');
      }
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'QuranX',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Search Surah / Juz'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchScreen(repository: widget.repository),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Unduhan Quran & Audio'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DownloadsScreen(
                    repository: widget.repository,
                    audio: widget.audio,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              setState(() => tab = 3);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Log kesalahan'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
              );
            },
          ),
        ],
      ),
    ),
    appBar: AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          tooltip: 'Buka menu',
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(Icons.menu),
        ),
      ),
      title: const Text(
        'QuranX',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: 'Search',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchScreen(repository: widget.repository),
            ),
          ),
          icon: const Icon(Icons.search),
        ),
      ],
    ),
    body: Column(
      children: [
        ListenableBuilder(
          listenable: widget.network,
          builder: (context, child) => widget.network.online
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: const Text(
                    'Offline mode: hanya data dan audio yang sudah diunduh yang tersedia.',
                  ),
                ),
        ),
        Expanded(
          child: IndexedStack(
            index: tab,
            children: [
              _homeTab(context),
              _quranTab(context),
              _bookmarksTab(context),
              _settingsTab(context),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Quran',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark_outline),
          selectedIcon: Icon(Icons.bookmark),
          label: 'Bookmark',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    ),
  );

  Widget _homeTab(BuildContext context) {
    final last = widget.repository.store.lastRead();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/brand/bibz_islamic_logo.png',
                  width: 76,
                  height: 76,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Assalamu’alaikum', style: TextStyle(fontSize: 15)),
              SizedBox(height: 8),
              Text(
                'Lanjutkan tilawah dengan tenang.',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 14),
              Text(
                'Data yang sudah dibuka tersimpan aman untuk digunakan offline.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (last != null)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.play_arrow)),
              title: Text('Lanjutkan Surah ${last['surah']}'),
              subtitle: Text('Ayat ${last['ayah']}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSurah(
                context,
                last['surah'] as int,
                last['ayah'] as int,
              ),
            ),
          ),
        const SizedBox(height: 18),
        TextField(
          controller: searchController,
          onSubmitted: runSearch,
          decoration: InputDecoration(
            labelText: 'Cari ayat lokal atau online',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    onPressed: () => runSearch(searchController.text),
                    icon: const Icon(Icons.arrow_forward),
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        if (searchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...searchResults
              .take(8)
              .map(
                (result) => Card(
                  child: ListTile(
                    title: Text(
                      'QS. ${result['surahNumber']}:${result['ayahNumber']}',
                    ),
                    subtitle: Text(result['translationId'] as String? ?? ''),
                    onTap: () => _openSurah(
                      context,
                      result['surahNumber'] as int,
                      result['ayahNumber'] as int,
                    ),
                  ),
                ),
              ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Surah pilihan',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...surahCatalog.take(5).map((surah) => _surahTile(context, surah)),
      ],
    );
  }

  Widget _quranTab(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 8, 14),
        child: Text(
          '114 Surah',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      ...surahCatalog.map((surah) => _surahTile(context, surah)),
    ],
  );

  Widget _surahTile(BuildContext context, SurahSummary summary) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Text('${summary.number}'),
      ),
      title: Text(
        summary.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${summary.ayahCount} ayat'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openSurah(context, summary.number, 1),
    ),
  );

  Widget _bookmarksTab(BuildContext context) {
    final values = widget.repository.store.bookmarks();
    if (values.isEmpty) return const Center(child: Text('Belum ada bookmark.'));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Bookmark',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        ...values.map((key) {
          final parts = key.split(':');
          return ListTile(
            leading: const Icon(Icons.bookmark),
            title: Text('QS. ${parts[0]}:${parts[1]}'),
            onTap: () =>
                _openSurah(context, int.parse(parts[0]), int.parse(parts[1])),
          );
        }),
      ],
    );
  }

  Widget _settingsTab(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Pengaturan',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      AppearanceSettingsCard(
        appearance: widget.appearance,
        onChanged: widget.onAppearanceChanged,
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Unduh Quran / Audio'),
          subtitle: const Text(
            'Pilih surah dan jenis data yang ingin disimpan offline.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DownloadsScreen(
                repository: widget.repository,
                audio: widget.audio,
              ),
            ),
          ),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.offline_bolt),
          title: const Text('Offline-first'),
          subtitle: const Text(
            'Surah dan audio yang sudah diunduh tetap tersedia tanpa internet.',
          ),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.storage_outlined),
          title: const Text('Penyimpanan'),
          subtitle: Text(
            '${widget.repository.store.bookmarks().length} bookmark tersimpan lokal.',
          ),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Log kesalahan dan crash'),
          subtitle: const Text(
            'Lihat dan salin full error beserta stack trace.',
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
          ),
        ),
      ),
      const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Tentang QuranX'),
          subtitle: Text('API: bibzislamicc.vercel.app/api/v1'),
        ),
      ),
    ],
  );

  Future<void> _openSurah(BuildContext context, int number, int ayah) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          repository: widget.repository,
          number: number,
          initialAyah: ayah,
          appearance: widget.appearance,
          audio: widget.audio,
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.repository,
    required this.number,
    required this.initialAyah,
    required this.appearance,
    required this.audio,
  });
  final QuranRepository repository;
  final int number;
  final int initialAyah;
  final QuranXAppearance appearance;
  final AudioController audio;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  Surah? surah;
  Object? error;
  bool loading = true;
  final scrollController = ScrollController();
  int? tajwidAyah;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final value = await widget.repository.getSurah(widget.number);
      if (mounted) {
        setState(() {
          surah = value;
          loading = false;
        });
      }
    } catch (value, stack) {
      final detail = DiagnosticLog.record(
        value,
        stack,
        context: 'reader.load.${widget.number}',
      );
      if (mounted) {
        setState(() {
          error = detail;
          loading = false;
        });
      }
    }
  }

  Future<void> _toggleBookmark(Ayah ayah) async {
    final key = '${widget.number}:${ayah.number}';
    final values = widget.repository.store.bookmarks();
    values.contains(key) ? values.remove(key) : values.add(key);
    await widget.repository.store.setBookmarks(values);
    if (mounted) setState(() {});
  }

  Future<void> _playAyah(Ayah ayah) async {
    try {
      final localPath = widget.repository.store.preferences.getString(
        'audio_path_${widget.number}',
      );
      if (localPath != null && await File(localPath).exists()) {
        await widget.audio.playFile(File(localPath));
      } else if (ayah.audioUrl != null) {
        await widget.audio.playUrl(ayah.audioUrl!);
      } else {
        throw const FormatException('Audio ayat belum tersedia');
      }
      if (mounted) setState(() {});
    } catch (error, stack) {
      final detail = DiagnosticLog.record(
        error,
        stack,
        context: 'reader.play.${widget.number}.${ayah.number}',
      );
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Audio tidak dapat diputar'),
            content: SizedBox(
              width: 420,
              height: 500,
              child: ErrorDetailsView(
                title: 'Audio tidak tersedia',
                detail: detail,
                onRetry: () => Navigator.pop(dialogContext),
                onLogConsumed: () => DiagnosticLog.deleteForDetail(detail),
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _copyAyah(Ayah ayah) async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${ayah.arabic}\n\n${ayah.translation}\n(QS. ${widget.number}:${ayah.number})',
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ayat disalin.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Surah belum termuat')),
        body: ErrorDetailsView(
          title: 'Surah belum tersedia',
          detail: error.toString(),
          onLogConsumed: () => DiagnosticLog.deleteForDetail(error.toString()),
          onRetry: () => setState(() {
            error = null;
            loading = true;
            _load();
          }),
        ),
      );
    }
    final data = surah!;
    return Scaffold(
      appBar: AppBar(title: Text(data.nameLatin)),
      body: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        itemCount: data.ayahs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _header(data);
          return _ayahCard(data.ayahs[index - 1]);
        },
      ),
    );
  }

  Widget _header(Surah data) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.nameArabic,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${data.revelationType} • ${data.ayahs.length} ayat',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          data.meaning,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          data.description,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _ayahCard(Ayah ayah) {
    final key = '${widget.number}:${ayah.number}';
    final marked = widget.repository.store.bookmarks().contains(key);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  child: Text(
                    '${ayah.number}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Bookmark',
                  onPressed: () => _toggleBookmark(ayah),
                  icon: Icon(
                    marked ? Icons.bookmark : Icons.bookmark_border,
                    color: marked
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Salin',
                  onPressed: () => _copyAyah(ayah),
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _playAyah(ayah),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Putar audio'),
                ),
                const SizedBox(width: 8),
                if (widget.audio.playing && widget.audio.currentSource != null)
                  OutlinedButton.icon(
                    onPressed: widget.audio.pause,
                    icon: const Icon(Icons.pause),
                    label: const Text('Jeda'),
                  ),
                const Spacer(),
                if (widget.appearance.tajwidMode)
                  IconButton(
                    tooltip: 'Analisis Tajwid',
                    onPressed: () => setState(
                      () => tajwidAyah = tajwidAyah == ayah.number
                          ? null
                          : ayah.number,
                    ),
                    icon: Icon(
                      tajwidAyah == ayah.number
                          ? Icons.visibility
                          : Icons.auto_awesome,
                    ),
                  ),
              ],
            ),
            Text(
              ayah.arabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 29, height: 1.8),
            ),
            if (tajwidAyah == ayah.number) TajwidPanel(text: ayah.arabic),
            const SizedBox(height: 8),
            Text(
              ayah.transliteration,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ayah.translation,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await widget.repository.store.saveLastRead(
                    widget.number,
                    ayah.number,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Posisi baca disimpan.')),
                    );
                  }
                },
                child: const Text('Tandai terakhir dibaca'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
