part of 'main.dart';

/// User-facing appearance settings persisted independently from Quran content.
class QuranXAppearance {
  const QuranXAppearance({
    this.themePreference = AppThemePreference.system,
    this.colorPreset = 'emerald',
    this.fontFamily = 'system',
    this.textScale = 1.0,
    this.showTranslation = true,
    this.showTransliteration = true,
    this.tajwidMode = false,
  });

  final AppThemePreference themePreference;
  final String colorPreset;
  final String fontFamily;
  final double textScale;
  final bool showTranslation;
  final bool showTransliteration;
  final bool tajwidMode;

  ThemeMode get themeMode {
    switch (themePreference) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  Color get seedColor {
    switch (colorPreset) {
      case 'navy':
        return const Color(0xff1e40af);
      case 'amber':
        return const Color(0xffb45309);
      case 'rose':
        return const Color(0xffbe123c);
      case 'emerald':
      default:
        return const Color(0xff0e6b55);
    }
  }

  String get resolvedFontFamily {
    switch (fontFamily) {
      case 'serif':
        return 'serif';
      case 'mono':
        return 'monospace';
      case 'system':
      default:
        return 'sans-serif';
    }
  }

  QuranXAppearance copyWith({
    AppThemePreference? themePreference,
    String? colorPreset,
    String? fontFamily,
    double? textScale,
    bool? showTranslation,
    bool? showTransliteration,
    bool? tajwidMode,
  }) => QuranXAppearance(
    themePreference: themePreference ?? this.themePreference,
    colorPreset: colorPreset ?? this.colorPreset,
    fontFamily: fontFamily ?? this.fontFamily,
    textScale: textScale ?? this.textScale,
    showTranslation: showTranslation ?? this.showTranslation,
    showTransliteration: showTransliteration ?? this.showTransliteration,
    tajwidMode: tajwidMode ?? this.tajwidMode,
  );
}

extension AppearanceStore on LocalStore {
  QuranXAppearance appearance() => QuranXAppearance(
    themePreference: themePreference(),
    colorPreset: preferences.getString('color_preset') ?? 'emerald',
    fontFamily: preferences.getString('font_family') ?? 'system',
    textScale: preferences.getDouble('text_scale') ?? 1.0,
    showTranslation: preferences.getBool('show_translation') ?? true,
    showTransliteration: preferences.getBool('show_transliteration') ?? true,
    tajwidMode: preferences.getBool('tajwid_mode') ?? false,
  );

  Future<void> saveAppearance(QuranXAppearance value) async {
    await Future.wait([
      setThemePreference(value.themePreference),
      preferences.setString('color_preset', value.colorPreset),
      preferences.setString('font_family', value.fontFamily),
      preferences.setDouble('text_scale', value.textScale),
      preferences.setBool('show_translation', value.showTranslation),
      preferences.setBool('show_transliteration', value.showTransliteration),
      preferences.setBool('tajwid_mode', value.tajwidMode),
    ]);
  }
}

class DiagnosticLog {
  static final List<String> entries = <String>[];
  static SharedPreferences? _preferences;

  static Future<void> initialize(SharedPreferences preferences) async {
    _preferences = preferences;
    entries
      ..clear()
      ..addAll(preferences.getStringList('diagnostic_log') ?? const <String>[]);
    if (entries.length > 20) {
      entries.removeRange(0, entries.length - 20);
    }
  }

  static String record(
    Object error,
    StackTrace stack, {
    String context = 'unknown',
  }) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final detail = [
      '[$timestamp] QuranX error',
      'context: $context',
      'error: ${error.runtimeType}',
      'message: $error',
      'stackTrace:',
      stack.toString(),
    ].join('\n');
    entries.add(detail);
    if (entries.length > 20) entries.removeAt(0);
    _preferences?.setStringList('diagnostic_log', List<String>.from(entries));
    developer.log(detail, name: 'QuranX', error: error, stackTrace: stack);
    return detail;
  }

  static String get latest => entries.isEmpty
      ? 'Belum ada error yang tercatat pada sesi ini.'
      : entries.last;

  static String get all => entries.isEmpty
      ? 'Belum ada error yang tercatat pada sesi ini.'
      : entries.join('\n\n----------------------------------------\n\n');
}

class NetworkMonitor extends ChangeNotifier {
  NetworkMonitor() {
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      final online = result.any((item) => item != ConnectivityResult.none);
      if (online != _online) {
        _online = online;
        notifyListeners();
      }
    });
    Connectivity().checkConnectivity().then((result) {
      _online = result.any((item) => item != ConnectivityResult.none);
      notifyListeners();
    });
  }

  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _online = true;
  bool get online => _online;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AudioController extends ChangeNotifier {
  AudioController() {
    _player.playerStateStream.listen((state) {
      _playing = state.playing;
      _processingState = state.processingState;
      notifyListeners();
    });
  }

  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _loading = false;
  ProcessingState _processingState = ProcessingState.idle;
  String? currentSource;
  String? lastError;

  bool get playing => _playing;
  ProcessingState get processingState => _processingState;

  Future<void> playUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      throw const FormatException('Sumber audio tidak aman atau tidak valid');
    }
    if (_loading) return;
    _loading = true;
    try {
      lastError = null;
      currentSource = url;
      await _player.stop();
      await _player.setUrl(url);
      await _player.play();
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      rethrow;
    } finally {
      _loading = false;
    }
  }

  Future<void> playFile(File file) async {
    if (!await file.exists()) {
      throw const FileSystemException('File audio offline tidak ditemukan');
    }
    if (_loading) return;
    _loading = true;
    try {
      lastError = null;
      currentSource = file.path;
      await _player.stop();
      await _player.setFilePath(file.path);
      await _player.play();
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      rethrow;
    } finally {
      _loading = false;
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _player.dispose();
    super.dispose();
  }
}

class DownloadManager extends ChangeNotifier {
  DownloadManager(this.repository);
  final QuranRepository repository;
  final http.Client _client = http.Client();
  final Map<String, double> progress = <String, double>{};
  final Map<String, String> errors = <String, String>{};

  Future<Directory> _audioDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/quranx/audio');
    await directory.create(recursive: true);
    return directory;
  }

  bool hasSurah(int number) => repository.store.readSurah(number) != null;

  File? audioFile(int number) {
    final path = repository.store.preferences.getString('audio_path_$number');
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  bool hasAudio(int number) => audioFile(number) != null;

  Future<void> downloadSurah(Surah surah) async {
    final key = 'surah:${surah.number}';
    progress[key] = 0.1;
    errors.remove(key);
    notifyListeners();
    try {
      await repository.store.saveSurah(surah);
      progress[key] = 1.0;
      notifyListeners();
    } catch (error, stack) {
      errors[key] = DiagnosticLog.record(
        error,
        stack,
        context: 'download.surah.${surah.number}',
      );
      progress.remove(key);
      notifyListeners();
      rethrow;
    }
  }

  Future<File> downloadAudio(Surah surah) async {
    final url = surah.fullAudioUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      throw const FormatException(
        'URL audio surah tidak tersedia atau tidak aman',
      );
    }
    final key = 'audio:${surah.number}';
    progress[key] = 0.0;
    errors.remove(key);
    notifyListeners();
    File? temporary;
    try {
      final request = http.Request('GET', uri);
      final response = await _client
          .send(request)
          .timeout(const Duration(minutes: 3));
      if (response.statusCode != 200) {
        throw ApiException('Unduh audio gagal: HTTP ${response.statusCode}');
      }
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('audio') &&
          !contentType.contains('octet-stream')) {
        throw ApiException('Respons audio tidak memiliki content-type audio');
      }
      final total = response.contentLength;
      final directory = await _audioDirectory();
      temporary = File('${directory.path}/surah_${surah.number}.mp3.part');
      final target = File('${directory.path}/surah_${surah.number}.mp3');
      if (await temporary.exists()) await temporary.delete();
      final sink = temporary.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(minutes: 3),
        )) {
          sink.add(chunk);
          received += chunk.length;
          if (total != null && total > 0) {
            progress[key] = received / total;
            notifyListeners();
          }
        }
        await sink.flush();
        await sink.close();
      } catch (_) {
        await sink.close();
        rethrow;
      }
      if (!await temporary.exists() || await temporary.length() < 1024) {
        throw const FileSystemException(
          'File sementara audio gagal diverifikasi',
        );
      }
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      await repository.store.preferences.setString(
        'audio_path_${surah.number}',
        target.path,
      );
      progress[key] = 1.0;
      notifyListeners();
      return target;
    } catch (error, stack) {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
      errors[key] = DiagnosticLog.record(
        error,
        stack,
        context: 'download.audio.${surah.number}',
      );
      progress.remove(key);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeAudio(int number) async {
    final file = audioFile(number);
    if (file != null && await file.exists()) await file.delete();
    await repository.store.preferences.remove('audio_path_$number');
    notifyListeners();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class TajwidResult {
  const TajwidResult({
    required this.originalText,
    required this.totalRules,
    required this.rules,
    required this.guidance,
  });

  final String originalText;
  final int totalRules;
  final List<String> rules;
  final String guidance;

  factory TajwidResult.fromJson(Map<String, dynamic> json) {
    final rawRules = (json['rulesDetected'] as List? ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .map((item) => item['ruleName'] as String? ?? 'Aturan tidak bernama')
        .toList();
    return TajwidResult(
      originalText: json['originalText'] as String? ?? '',
      totalRules: json['totalRulesDetected'] as int? ?? rawRules.length,
      rules: rawRules,
      guidance: json['recitationGuidance'] as String? ?? '',
    );
  }
}

class TajwidService {
  TajwidService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<TajwidResult> analyze(String text) async {
    final response = await _client
        .get(Uri.parse('$apiBaseUrl/quran/tajwid'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException('Analisis Tajwid gagal: HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw ApiException(body['message'] as String? ?? 'Analisis Tajwid gagal');
    }
    final result = TajwidResult.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
    if (result.originalText.isEmpty) {
      throw const FormatException('Respons Tajwid tidak memiliki teks sumber');
    }
    return result;
  }
}

class ErrorDetailsView extends StatelessWidget {
  const ErrorDetailsView({
    super.key,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final String title;
  final String detail;
  final VoidCallback? onRetry;

  String _issueBody() {
    const maxReportLength = 7000;
    if (detail.length <= maxReportLength) return detail;
    return '${detail.substring(0, maxReportLength)}\n\n[Log dipotong pada 7000 karakter. Gunakan Copy Full Error Log untuk log lengkap.]';
  }

  Future<void> _reportIssue(BuildContext context) async {
    final issueUrl = Uri.https(
      'github.com',
      '/XbibzOfficial777/Bibz-Islamic-App/issues/new',
      <String, String>{
        'title': '[QuranX] ${title.replaceAll(RegExp(r'\s+'), ' ').trim()}',
        'body':
            '## QuranX error report\n\nGenerated from the in-app Report Issue action.\n\n```text\n${_issueBody()}\n```',
        'labels': 'bug',
      },
    );
    final launched = await launchUrl(
      issueUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'GitHub tidak dapat dibuka. Salin log lalu buat issue secara manual.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Icon(
        Icons.error_outline,
        size: 56,
        color: Theme.of(context).colorScheme.error,
      ),
      const SizedBox(height: 12),
      Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      const Text(
        'Data valid sebelumnya tetap dipertahankan. Salin log lengkap atau laporkan masalah dengan detail teknis yang sudah diisi.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      SelectableText(
        detail,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: detail));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Full error log disalin.')),
            );
          }
        },
        icon: const Icon(Icons.copy),
        label: const Text('Copy Full Error Log'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _reportIssue(context),
        icon: const Icon(Icons.bug_report_outlined),
        label: const Text('Report Issue'),
      ),
      if (onRetry != null) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Coba lagi'),
        ),
      ],
    ],
  );
}

class AppearanceSettingsCard extends StatelessWidget {
  const AppearanceSettingsCard({
    super.key,
    required this.appearance,
    required this.onChanged,
  });
  final QuranXAppearance appearance;
  final Future<void> Function(QuranXAppearance) onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tampilan & bacaan',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          DropdownButtonFormField<AppThemePreference>(
            initialValue: appearance.themePreference,
            decoration: const InputDecoration(labelText: 'Tema'),
            items: const [
              DropdownMenuItem(
                value: AppThemePreference.system,
                child: Text('Sistem'),
              ),
              DropdownMenuItem(
                value: AppThemePreference.light,
                child: Text('Light'),
              ),
              DropdownMenuItem(
                value: AppThemePreference.dark,
                child: Text('Dark'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(appearance.copyWith(themePreference: value));
              }
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: appearance.colorPreset,
            decoration: const InputDecoration(labelText: 'Warna aksen'),
            items: const [
              DropdownMenuItem(value: 'emerald', child: Text('Emerald')),
              DropdownMenuItem(value: 'navy', child: Text('Navy')),
              DropdownMenuItem(value: 'amber', child: Text('Amber')),
              DropdownMenuItem(value: 'rose', child: Text('Rose')),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(appearance.copyWith(colorPreset: value));
              }
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: appearance.fontFamily,
            decoration: const InputDecoration(labelText: 'Font antarmuka'),
            items: const [
              DropdownMenuItem(value: 'system', child: Text('System Sans')),
              DropdownMenuItem(value: 'serif', child: Text('Serif')),
              DropdownMenuItem(value: 'mono', child: Text('Monospace')),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(appearance.copyWith(fontFamily: value));
              }
            },
          ),
          const SizedBox(height: 8),
          Text('Ukuran teks: ${(appearance.textScale * 100).round()}%'),
          Slider(
            value: appearance.textScale,
            min: 0.85,
            max: 1.45,
            divisions: 12,
            label: '${(appearance.textScale * 100).round()}%',
            onChanged: (value) =>
                onChanged(appearance.copyWith(textScale: value)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tampilkan transliterasi'),
            value: appearance.showTransliteration,
            onChanged: (value) =>
                onChanged(appearance.copyWith(showTransliteration: value)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tampilkan terjemahan'),
            value: appearance.showTranslation,
            onChanged: (value) =>
                onChanged(appearance.copyWith(showTranslation: value)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tajwid Mode'),
            subtitle: const Text(
              'Menampilkan panel analisis tajwid yang tersedia dari API.',
            ),
            value: appearance.tajwidMode,
            onChanged: (value) =>
                onChanged(appearance.copyWith(tajwidMode: value)),
          ),
        ],
      ),
    ),
  );
}

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Log kesalahan')),
    body: ErrorDetailsView(
      title: 'Diagnostik sesi QuranX',
      detail: DiagnosticLog.all,
    ),
  );
}

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({
    super.key,
    required this.repository,
    required this.audio,
  });
  final QuranRepository repository;
  final AudioController audio;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late final DownloadManager manager;
  final Set<int> selected = <int>{};
  bool loading = false;
  String? message;

  @override
  void initState() {
    super.initState();
    manager = DownloadManager(widget.repository)..addListener(_refresh);
  }

  @override
  void dispose() {
    manager.removeListener(_refresh);
    manager.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<Surah?> _getSurah(int number) async {
    try {
      return await widget.repository.getSurah(number);
    } catch (error, stack) {
      final detail = DiagnosticLog.record(
        error,
        stack,
        context: 'downloads.load.$number',
      );
      if (mounted) setState(() => message = detail);
      return null;
    }
  }

  Future<void> _downloadSelected({required bool audio}) async {
    if (selected.isEmpty) {
      setState(() => message = 'Pilih minimal satu surah terlebih dahulu.');
      return;
    }
    setState(() {
      loading = true;
      message = null;
    });
    for (final number in selected.toList()..sort()) {
      final surah = await _getSurah(number);
      if (surah == null) {
        continue;
      }
      try {
        if (audio) {
          await manager.downloadAudio(surah);
        } else {
          await manager.downloadSurah(surah);
        }
      } catch (error, stack) {
        if (mounted) {
          setState(
            () => message = DiagnosticLog.record(
              error,
              stack,
              context: 'downloads.batch.${audio ? 'audio' : 'quran'}.$number',
            ),
          );
        }
      }
    }
    if (mounted) {
      setState(() {
        loading = false;
        selected.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Unduhan offline')),
    body: Column(
      children: [
        if (message != null)
          SizedBox(
            height: 270,
            child: ErrorDetailsView(
              title: 'Unduhan gagal',
              detail: message!,
              onRetry: () => setState(() => message = null),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: loading
                      ? null
                      : () => _downloadSelected(audio: false),
                  icon: const Icon(Icons.menu_book),
                  label: const Text('Unduh Quran'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : () => _downloadSelected(audio: true),
                  icon: const Icon(Icons.headphones),
                  label: const Text('Unduh Audio'),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Pilih surah yang ingin disimpan. Data ditulis ke file sementara dan baru dianggap selesai setelah validasi.',
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: surahCatalog.length,
            itemBuilder: (context, index) {
              final summary = surahCatalog[index];
              final quranReady = manager.hasSurah(summary.number);
              final audioReady = manager.hasAudio(summary.number);
              return CheckboxListTile(
                value: selected.contains(summary.number),
                onChanged: (value) => setState(() {
                  value == true
                      ? selected.add(summary.number)
                      : selected.remove(summary.number);
                }),
                title: Text('${summary.number}. ${summary.name}'),
                subtitle: Text(
                  '${quranReady ? 'Quran tersedia' : 'Quran belum diunduh'} • ${audioReady ? 'audio tersedia' : 'audio belum diunduh'}',
                ),
                secondary: Icon(
                  quranReady && audioReady
                      ? Icons.download_done
                      : Icons.cloud_download_outlined,
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class JuzRange {
  const JuzRange(this.startSurah, this.startAyah, this.endSurah, this.endAyah);
  final int startSurah;
  final int startAyah;
  final int endSurah;
  final int endAyah;
}

const canonicalJuzRanges = <JuzRange>[
  JuzRange(1, 1, 2, 141),
  JuzRange(2, 142, 2, 252),
  JuzRange(2, 253, 3, 92),
  JuzRange(3, 93, 4, 23),
  JuzRange(4, 24, 4, 147),
  JuzRange(4, 148, 5, 81),
  JuzRange(5, 82, 6, 110),
  JuzRange(6, 111, 7, 87),
  JuzRange(7, 88, 8, 40),
  JuzRange(8, 41, 9, 92),
  JuzRange(9, 93, 11, 5),
  JuzRange(11, 6, 12, 52),
  JuzRange(12, 53, 14, 52),
  JuzRange(15, 1, 16, 128),
  JuzRange(17, 1, 18, 74),
  JuzRange(18, 75, 20, 135),
  JuzRange(21, 1, 23, 118),
  JuzRange(23, 119, 25, 20),
  JuzRange(25, 21, 27, 55),
  JuzRange(27, 56, 29, 45),
  JuzRange(29, 46, 33, 30),
  JuzRange(33, 31, 36, 27),
  JuzRange(36, 28, 39, 31),
  JuzRange(39, 32, 41, 46),
  JuzRange(41, 47, 45, 37),
  JuzRange(45, 38, 51, 30),
  JuzRange(51, 31, 57, 29),
  JuzRange(58, 1, 66, 12),
  JuzRange(66, 13, 72, 28),
  JuzRange(73, 1, 77, 50),
  JuzRange(78, 1, 114, 6),
];

bool _inJuzRange(int surah, int ayah, JuzRange range) {
  final current = surah * 1000 + ayah;
  final start = range.startSurah * 1000 + range.startAyah;
  final end = range.endSurah * 1000 + range.endAyah;
  return current >= start && current <= end;
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.repository});
  final QuranRepository repository;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();
  late final AudioController audio;
  String mode = 'surah';
  List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
  String? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    audio = AudioController();
  }

  @override
  void dispose() {
    controller.dispose();
    audio.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        results = [];
        error = 'Masukkan nama/nomor surah atau nomor Juz.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (mode == 'juz') {
        final juz = int.tryParse(query);
        if (juz == null || juz < 1 || juz > 30) {
          throw const FormatException('Nomor Juz harus 1 sampai 30.');
        }
        results = widget.repository.searchJuz(juz);
        if (results.isEmpty) {
          error = 'Metadata Juz belum tersedia pada data yang tersimpan. Unduh surah dari sumber yang menyertakan field Juz terlebih dahulu.';
        }
      } else {
        results = widget.repository.searchSurah(query);
        if (results.isEmpty) {
          error = 'Surah tidak ditemukan di katalog.';
        }
      }
    } catch (value, stack) {
      error = DiagnosticLog.record(value, stack, context: 'search.$mode');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Search Quran')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'surah',
                label: Text('Surah'),
                icon: Icon(Icons.menu_book),
              ),
              ButtonSegment(
                value: 'juz',
                label: Text('Juz'),
                icon: Icon(Icons.bookmarks),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (value) => setState(() {
              mode = value.first;
              results = [];
              error = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: mode == 'juz'
                  ? 'Nomor Juz (1–30)'
                  : 'Nama atau nomor surah',
              suffixIcon: IconButton(
                onPressed: _search,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!, textAlign: TextAlign.center),
            ),
          Expanded(
            child: ListView(
              children: results
                  .map(
                    (item) => ListTile(
                      title: Text(item['title'] as String? ?? 'Hasil'),
                      subtitle: Text(item['subtitle'] as String? ?? ''),
                      onTap: () {
                        final number = item['surahNumber'] as int;
                        final ayah = item['ayahNumber'] as int? ?? 1;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReaderScreen(
                              repository: widget.repository,
                              number: number,
                              initialAyah: ayah,
                              appearance: widget.repository.store.appearance(),
                              audio: audio,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    ),
  );
}

class TajwidPanel extends StatefulWidget {
  const TajwidPanel({super.key, required this.text});
  final String text;
  @override
  State<TajwidPanel> createState() => _TajwidPanelState();
}

class _TajwidPanelState extends State<TajwidPanel> {
  late Future<TajwidResult> future;
  @override
  void initState() {
    super.initState();
    future = TajwidService().analyze(widget.text);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TajwidResult>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(),
        );
      }
      if (snapshot.hasError) {
        return ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Tajwid Mode tidak tersedia'),
          subtitle: Text('${snapshot.error}'),
        );
      }
      final data = snapshot.data!;
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tajwid Mode',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('API mendeteksi ${data.totalRules} kelompok aturan.'),
              ...data.rules.map((rule) => Text('• $rule')),
              if (data.guidance.isNotEmpty) Text(data.guidance),
            ],
          ),
        ),
      );
    },
  );
}
