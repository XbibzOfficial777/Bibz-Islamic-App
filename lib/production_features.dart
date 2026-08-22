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

class DiagnosticLogFile {
  const DiagnosticLogFile({
    required this.name,
    required this.path,
    required this.displayPath,
    this.id,
  });

  final String name;
  final String path;
  final String displayPath;
  final String? id;

  factory DiagnosticLogFile.fromMap(Map<Object?, Object?> map) {
    return DiagnosticLogFile(
      name: map['name'] as String? ?? 'QuranX_Log.txt',
      path: map['path'] as String? ?? '',
      displayPath: map['displayPath'] as String? ?? '',
      id: map['id'] as String?,
    );
  }
}

class DiagnosticFileStore {
  static const MethodChannel _channel = MethodChannel('quranx/diagnostics');

  static Future<DiagnosticLogFile> write({
    required String name,
    required String contents,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'writeLog',
        <String, Object?>{'fileName': name, 'contents': contents},
      );
      if (result != null) return DiagnosticLogFile.fromMap(result);
    } on PlatformException catch (error, stack) {
      developer.log(
        'Native diagnostic storage unavailable: $error',
        name: 'QuranX.diagnostics',
        stackTrace: stack,
      );
    } on MissingPluginException {
      // Flutter unit tests and non-Android platforms use the Dart fallback.
    }

    try {
      final root = await getApplicationSupportDirectory();
      final directory = Directory('${root.path}/QuranX/Logs');
      await directory.create(recursive: true);
      final file = File('${directory.path}/$name');
      await file.writeAsString(contents, flush: true);
      return DiagnosticLogFile(
        name: name,
        path: file.path,
        displayPath: file.path,
      );
    } catch (error, stack) {
      developer.log(
        'Diagnostic fallback write failed: $error',
        name: 'QuranX.diagnostics',
        stackTrace: stack,
      );
      return DiagnosticLogFile(
        name: name,
        path: '',
        displayPath: 'Tidak tersedia',
      );
    }
  }

  static Future<String> directoryDescription() async {
    try {
      final result = await _channel.invokeMethod<String>('getLogDirectory');
      if (result != null && result.isNotEmpty) return result;
    } on PlatformException catch (error, stack) {
      developer.log(
        'Native diagnostic path unavailable: $error',
        name: 'QuranX.diagnostics',
        stackTrace: stack,
      );
    } on MissingPluginException {
      // Flutter unit tests and non-Android platforms use the Dart fallback.
    }
    try {
      final root = await getApplicationSupportDirectory();
      return '${root.path}/QuranX/Logs';
    } catch (_) {
      return 'Penyimpanan aplikasi QuranX/Logs';
    }
  }

  static Future<List<DiagnosticLogFile>> list() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('listLogs');
      if (result != null) {
        return result
            .whereType<Map<Object?, Object?>>()
            .map(DiagnosticLogFile.fromMap)
            .toList();
      }
    } on PlatformException catch (error, stack) {
      developer.log(
        'Native diagnostic listing unavailable: $error',
        name: 'QuranX.diagnostics',
        stackTrace: stack,
      );
    } on MissingPluginException {
      // Flutter unit tests and non-Android platforms use the Dart fallback.
    }

    try {
      final root = await getApplicationSupportDirectory();
      final directory = Directory('${root.path}/QuranX/Logs');
      if (!await directory.exists()) return const <DiagnosticLogFile>[];
      final files = await directory
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.txt'))
          .toList();
      return files
          .whereType<File>()
          .map(
            (file) => DiagnosticLogFile(
              name: file.uri.pathSegments.last,
              path: file.path,
              displayPath: file.path,
            ),
          )
          .toList()
        ..sort((a, b) => b.name.compareTo(a.name));
    } catch (error, stack) {
      developer.log(
        'Diagnostic fallback listing failed: $error',
        name: 'QuranX.diagnostics',
        stackTrace: stack,
      );
      return const <DiagnosticLogFile>[];
    }
  }

  static Future<void> deleteAll() async {
    try {
      final result = await _channel.invokeMethod<bool>('deleteAllLogs');
      if (result == true) return;
    } on PlatformException catch (error, stack) {
      developer.log(
        'Native diagnostic purge unavailable: $error',
        name: 'QuranX.diagnostics',
        stackTrace: stack,
      );
    } on MissingPluginException {
      // Flutter unit tests and non-Android platforms use the Dart fallback.
    }

    final files = await list();
    for (final file in files) {
      final local = File(file.path);
      if (await local.exists()) await local.delete();
    }
  }

  static Future<void> delete(String name) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'deleteLog',
        <String, Object?>{'fileName': name},
      );
      if (result == true) return;
    } on PlatformException catch (error, stack) {
      developer.log(
        'Native diagnostic deletion unavailable: $error',
        name: 'QuranX.diagnostics',
        stackTrace: stack,
      );
    } on MissingPluginException {
      // Flutter unit tests and non-Android platforms use the Dart fallback.
    }

    try {
      final root = await getApplicationSupportDirectory();
      final file = File('${root.path}/QuranX/Logs/$name');
      if (await file.exists()) await file.delete();
    } catch (error, stack) {
      developer.log(
        'Diagnostic fallback deletion failed: $error',
        name: 'QuranX.diagnostics',
        stackTrace: stack,
      );
    }
  }
}

class DiagnosticLog {
  static final List<String> entries = <String>[];
  static final Map<String, String> _fileNames = <String, String>{};
  static final Map<String, Future<void>> _pendingWrites =
      <String, Future<void>>{};
  static SharedPreferences? _preferences;
  static int _fileSequence = 0;

  static Future<void> initialize(SharedPreferences preferences) async {
    _preferences = preferences;
    _fileNames.clear();
    entries
      ..clear()
      ..addAll(preferences.getStringList('diagnostic_log') ?? const <String>[]);
    if (entries.length > 20) {
      entries.removeRange(0, entries.length - 20);
    }
    unawaited(DiagnosticFileStore.list());
  }

  static String record(
    Object error,
    StackTrace stack, {
    String context = 'unknown',
  }) {
    final now = DateTime.now();
    final timestamp = now.toUtc().toIso8601String();
    final detail = [
      '[$timestamp] QuranX error',
      'context: $context',
      'error: ${error.runtimeType}',
      'message: $error',
      'stackTrace:',
      stack.toString(),
    ].join('\n');
    final fileName = _fileName(now);
    entries.add(detail);
    _fileNames[detail] = fileName;
    if (entries.length > 20) {
      final removed = entries.removeAt(0);
      _fileNames.remove(removed);
    }
    unawaited(_saveEntries());
    final pendingWrite = _writeFile(fileName, detail);
    _pendingWrites[fileName] = pendingWrite;
    developer.log(detail, name: 'QuranX', error: error, stackTrace: stack);
    return detail;
  }

  static String _fileName(DateTime time) {
    _fileSequence = (_fileSequence + 1) % 1000;
    final local = time.toLocal();
    final stamp = [
      local.year.toString().padLeft(4, '0'),
      local.month.toString().padLeft(2, '0'),
      local.day.toString().padLeft(2, '0'),
      '_',
      local.hour.toString().padLeft(2, '0'),
      local.minute.toString().padLeft(2, '0'),
      local.second.toString().padLeft(2, '0'),
      '_',
      local.millisecond.toString().padLeft(3, '0'),
      _fileSequence.toString().padLeft(3, '0'),
    ].join();
    return 'QuranX_Log_$stamp.txt';
  }

  static Future<void> _writeFile(String fileName, String detail) async {
    try {
      await DiagnosticFileStore.write(name: fileName, contents: detail);
    } finally {
      _pendingWrites.remove(fileName);
    }
  }

  static Future<void> _saveEntries() async {
    await _preferences?.setStringList(
      'diagnostic_log',
      List<String>.from(entries),
    );
  }

  static String? fileNameFor(String detail) => _fileNames[detail];

  static Future<void> deleteForDetail(String detail) async {
    final fileName = _fileNames.remove(detail);
    entries.remove(detail);
    await _saveEntries();
    if (fileName != null) {
      await _pendingWrites[fileName];
      await DiagnosticFileStore.delete(fileName);
    }
  }

  static Future<void> deleteFile(String fileName) async {
    final matching = _fileNames.entries
        .where((entry) => entry.value == fileName)
        .map((entry) => entry.key)
        .toSet();
    for (final detail in matching) {
      _fileNames.remove(detail);
    }
    entries.removeWhere(matching.contains);
    await _saveEntries();
    await _pendingWrites[fileName];
    await DiagnosticFileStore.delete(fileName);
  }

  static Future<void> clearAll() async {
    final pending = List<Future<void>>.from(_pendingWrites.values);
    if (pending.isNotEmpty) await Future.wait(pending);
    entries.clear();
    _fileNames.clear();
    await _saveEntries();
    await DiagnosticFileStore.deleteAll();
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

class PrayerCity {
  const PrayerCity({required this.id, required this.name});

  final String id;
  final String name;

  factory PrayerCity.fromJson(Map<String, dynamic> json) => PrayerCity(
    id: '${json['id']}',
    name: json['lokasi'] as String? ?? 'Wilayah tidak bernama',
  );
}

class PrayerSchedule {
  const PrayerSchedule({
    required this.cityId,
    required this.cityName,
    required this.regionName,
    required this.date,
    required this.times,
  });

  final int cityId;
  final String cityName;
  final String regionName;
  final DateTime date;
  final Map<String, String> times;

  static const names = <String>[
    'imsak',
    'subuh',
    'terbit',
    'dhuha',
    'dzuhur',
    'ashar',
    'maghrib',
    'isya',
  ];

  factory PrayerSchedule.fromApi(
    Map<String, dynamic> body, {
    required int requestedCityId,
    required DateTime requestedDate,
  }) {
    if (body['success'] != true) {
      throw ApiException(
        body['message'] as String? ?? 'Jadwal sholat gagal dimuat',
      );
    }
    final data = Map<String, dynamic>.from(body['data'] as Map);
    if (data['isLiveDataFromInternet'] != true || data['schedule'] is! Map) {
      throw const FormatException(
        'Respons bukan jadwal Kemenag live untuk kota yang dipilih',
      );
    }
    final city = Map<String, dynamic>.from(data['cityInfo'] as Map);
    final cityId = int.tryParse('${city['id']}');
    if (cityId == null || cityId != requestedCityId) {
      throw const FormatException('Kota pada respons API tidak sesuai pilihan');
    }
    final rawSchedule = Map<String, dynamic>.from(data['schedule'] as Map);
    final isoDate = rawSchedule['date'] as String?;
    final date = isoDate == null ? null : DateTime.tryParse(isoDate);
    if (date == null ||
        date.year != requestedDate.year ||
        date.month != requestedDate.month ||
        date.day != requestedDate.day) {
      throw const FormatException('Tanggal jadwal API tidak sesuai permintaan');
    }
    final times = <String, String>{};
    for (final name in names) {
      final value = rawSchedule[name];
      if (value is! String || !RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) {
        throw FormatException('Waktu sholat $name tidak valid');
      }
      times[name] = value;
    }
    return PrayerSchedule(
      cityId: cityId,
      cityName: city['lokasi'] as String? ?? 'Wilayah tidak bernama',
      regionName: city['daerah'] as String? ?? '',
      date: DateTime(date.year, date.month, date.day),
      times: times,
    );
  }
}

class PrayerApiClient {
  PrayerApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<PrayerCity>> searchCities(String query) async {
    final encoded = Uri.encodeQueryComponent(query.trim());
    final response = await _client
        .get(Uri.parse('$apiBaseUrl/falak/cities?q=$encoded'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException('Daftar kota gagal: HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw ApiException(body['message'] as String? ?? 'Daftar kota gagal');
    }
    final data = Map<String, dynamic>.from(body['data'] as Map);
    return (data['cities'] as List)
        .map(
          (item) => PrayerCity.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<PrayerSchedule> fetchSchedule(int cityId, DateTime date) async {
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final response = await _client
        .get(
          Uri.parse(
            '$apiBaseUrl/falak/prayer-times?cityId=$cityId&date=$dateText',
          ),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException('Jadwal sholat gagal: HTTP ${response.statusCode}');
    }
    return PrayerSchedule.fromApi(
      jsonDecode(response.body) as Map<String, dynamic>,
      requestedCityId: cityId,
      requestedDate: date,
    );
  }

  void dispose() => _client.close();
}

class PrayerReminderService {
  PrayerReminderService(this.preferences);

  final SharedPreferences preferences;
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> requestNotificationPermission() async {
    await initialize();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  int _notificationId(String name, int dayOffset) =>
      5000 + dayOffset * 10 + PrayerSchedule.names.indexOf(name);

  AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        'quranx_prayer_times',
        'Jadwal Sholat QuranX',
        channelDescription: 'Pengingat waktu sholat QuranX',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
      );

  Future<void> schedule(
    PrayerSchedule schedule, {
    int leadMinutes = 0,
    int dayOffset = 0,
    bool clearExisting = true,
  }) async {
    await initialize();
    final granted = await requestNotificationPermission();
    if (!granted) {
      throw const FileSystemException(
        'Izin notifikasi belum diberikan untuk pengingat sholat.',
      );
    }
    if (clearExisting) await plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    final details = NotificationDetails(android: _androidDetails);
    for (final name in const ['subuh', 'dzuhur', 'ashar', 'maghrib', 'isya']) {
      final parts = schedule.times[name]!.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        throw const FormatException('Komponen waktu sholat tidak valid');
      }
      final base = tz.TZDateTime(
        tz.local,
        schedule.date.year,
        schedule.date.month,
        schedule.date.day,
        hour,
        minute,
      );
      final scheduled = base.subtract(Duration(minutes: leadMinutes));
      if (!scheduled.isAfter(now)) continue;
      await plugin.zonedSchedule(
        id: _notificationId(name, dayOffset),
        title: 'Notifikasi Sholat ${_displayName(name)}',
        body:
            '${_displayName(name)} ${schedule.times[name]} • ${schedule.cityName}',
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '${schedule.cityId}|${schedule.date.toIso8601String()}|$name',
      );
    }
    await preferences.setString('prayer_city_id', '${schedule.cityId}');
    await preferences.setString('prayer_city_name', schedule.cityName);
    await preferences.setString(
      'prayer_schedule_date',
      schedule.date.toIso8601String(),
    );
  }

  Future<void> scheduleSevenDays(
    PrayerApiClient api,
    int cityId, {
    int leadMinutes = 0,
  }) async {
    await initialize();
    final granted = await requestNotificationPermission();
    if (!granted) {
      throw const FileSystemException(
        'Izin notifikasi belum diberikan untuk pengingat sholat.',
      );
    }
    await plugin.cancelAll();
    final today = DateTime.now();
    PrayerSchedule? first;
    for (var offset = 0; offset < 7; offset++) {
      final date = DateTime(today.year, today.month, today.day + offset);
      final value = await api.fetchSchedule(cityId, date);
      first ??= value;
      await schedule(
        value,
        leadMinutes: leadMinutes,
        dayOffset: offset,
        clearExisting: false,
      );
    }
    if (first != null) {
      await preferences.setString('prayer_city_id', '$cityId');
      await preferences.setString('prayer_city_name', first.cityName);
    }
  }

  Future<void> cancel() async {
    await initialize();
    await plugin.cancelAll();
  }

  static String _displayName(String name) {
    switch (name) {
      case 'subuh':
        return 'Subuh';
      case 'dzuhur':
        return 'Dzuhur';
      case 'ashar':
        return 'Ashar';
      case 'maghrib':
        return 'Maghrib';
      case 'isya':
        return 'Isya';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }

  void dispose() {}
}

class BackgroundDownloadCoordinator extends ChangeNotifier {
  BackgroundDownloadCoordinator(this.repository);

  final QuranRepository repository;
  final FileDownloader downloader = FileDownloader();
  final Map<String, double> progress = <String, double>{};
  final Map<String, String> errors = <String, String>{};
  final Map<String, DownloadTask> _tasks = <String, DownloadTask>{};
  final Map<String, String> _taskIds = <String, String>{};
  StreamSubscription<TaskUpdate>? _updates;
  bool _initialized = false;
  bool _notificationPermissionRequested = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    downloader.configureNotification(
      running: const TaskNotification(
        'QuranX sedang mengunduh',
        '{displayName} • {progress}',
      ),
      complete: const TaskNotification(
        'Unduhan QuranX selesai',
        '{displayName}',
      ),
      error: const TaskNotification('Unduhan QuranX gagal', '{displayName}'),
      paused: const TaskNotification('Unduhan QuranX dijeda', '{displayName}'),
      canceled: const TaskNotification(
        'Unduhan QuranX dibatalkan',
        '{displayName}',
      ),
      progressBar: true,
    );
    _updates = downloader.updates.listen(_handleUpdate);
    await downloader.start(autoCleanDatabase: true);
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await initialize();
  }

  Future<void> _requestNotificationPermission() async {
    if (_notificationPermissionRequested) return;
    _notificationPermissionRequested = true;
    final permission = PermissionType.notifications;
    var status = await downloader.permissions.status(permission);
    if (status != PermissionStatus.granted) {
      status = await downloader.permissions.request(permission);
    }
    if (status != PermissionStatus.granted) {
      throw const FileSystemException(
        'Izin notifikasi diperlukan agar progress unduhan terlihat di bar notifikasi.',
      );
    }
  }

  String _key(String type, int number) => '$type:$number';

  bool hasSurah(int number) => repository.store.readSurah(number) != null;

  File? audioFile(int number) {
    final path = repository.store.preferences.getString('audio_path_$number');
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  bool hasAudio(int number) => audioFile(number) != null;

  Future<void> downloadSurah(Surah surah) async {
    await _enqueue(
      type: 'quran',
      number: surah.number,
      url: '$apiBaseUrl/quran/surah?surah=${surah.number}',
      filename: 'surah_${surah.number}.json',
      directory: 'quranx/quran',
      displayName: 'Quran ${surah.nameLatin}',
    );
  }

  Future<void> downloadAudio(Surah surah) async {
    final url = surah.fullAudioUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      throw const FormatException(
        'URL audio surah tidak tersedia atau tidak aman',
      );
    }
    await _enqueue(
      type: 'audio',
      number: surah.number,
      url: url!,
      filename: 'surah_${surah.number}.mp3',
      directory: 'quranx/audio',
      displayName: 'Audio ${surah.nameLatin}',
    );
  }

  Future<void> _enqueue({
    required String type,
    required int number,
    required String url,
    required String filename,
    required String directory,
    required String displayName,
  }) async {
    await _ensureInitialized();
    await _requestNotificationPermission();
    final key = _key(type, number);
    errors.remove(key);
    progress[key] = 0;
    final task = DownloadTask(
      taskId: 'quranx-$type-$number-${DateTime.now().microsecondsSinceEpoch}',
      url: url,
      filename: filename,
      directory: directory,
      baseDirectory: BaseDirectory.applicationSupport,
      group: 'quranx-$type',
      updates: Updates.statusAndProgress,
      retries: 5,
      allowPause: true,
      priority: 5,
      displayName: displayName,
      metaData: '$type:$number',
    );
    _tasks[task.taskId] = task;
    _taskIds[key] = task.taskId;
    notifyListeners();
    final enqueued = await downloader.enqueue(task);
    if (!enqueued) {
      progress.remove(key);
      errors[key] = 'Task unduhan tidak dapat dimasukkan ke antrean.';
      notifyListeners();
      throw const FileSystemException('Task unduhan gagal masuk antrean');
    }
  }

  Future<void> _handleUpdate(TaskUpdate update) async {
    final task = update.task;
    final parts = task.metaData.split(':');
    if (parts.length != 2) return;
    final type = parts[0];
    final number = int.tryParse(parts[1]);
    if (number == null) return;
    final key = _key(type, number);
    if (update is TaskProgressUpdate) {
      progress[key] = update.progress.clamp(0.0, 1.0);
      notifyListeners();
      return;
    }
    if (update is! TaskStatusUpdate) return;
    switch (update.status) {
      case TaskStatus.complete:
        await _finalizeCompleted(task, type, number, key);
      case TaskStatus.failed:
      case TaskStatus.notFound:
        progress.remove(key);
        errors[key] = DiagnosticLog.record(
          update.exception ?? 'Download task failed',
          StackTrace.current,
          context: 'background.download.$type.$number',
        );
        notifyListeners();
      case TaskStatus.canceled:
        progress.remove(key);
        errors[key] = 'Unduhan dibatalkan.';
        notifyListeners();
      case TaskStatus.paused:
      case TaskStatus.waitingToRetry:
      case TaskStatus.enqueued:
      case TaskStatus.running:
        notifyListeners();
    }
  }

  Future<void> _finalizeCompleted(
    Task task,
    String type,
    int number,
    String key,
  ) async {
    try {
      final path = await task.filePath();
      final file = File(path);
      if (!await file.exists()) {
        throw const FileSystemException('File hasil unduhan tidak ditemukan');
      }
      if (type == 'quran') {
        final raw =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final body = Map<String, dynamic>.from(raw);
        if (body['success'] != true || body['data'] is! Map) {
          throw const FormatException(
            'Respons Quran hasil unduhan tidak valid',
          );
        }
        final surah = Surah.fromJson(
          Map<String, dynamic>.from(body['data'] as Map),
        );
        if (surah.number != number) {
          throw const FormatException('Nomor surah hasil unduhan tidak sesuai');
        }
        await repository.store.saveSurah(surah);
      } else {
        if (await file.length() < 1024) {
          throw const FileSystemException(
            'File audio terlalu kecil atau rusak',
          );
        }
        await repository.store.preferences.setString(
          'audio_path_$number',
          path,
        );
      }
      progress[key] = 1;
      errors.remove(key);
      notifyListeners();
    } catch (error, stack) {
      progress.remove(key);
      errors[key] = DiagnosticLog.record(
        error,
        stack,
        context: 'background.finalize.$type.$number',
      );
      try {
        final path = await task.filePath();
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> cancel(int number, {required bool audio}) async {
    await _ensureInitialized();
    final key = _key(audio ? 'audio' : 'quran', number);
    final taskId = _taskIds[key];
    if (taskId == null) return;
    await downloader.cancelTaskWithId(taskId);
    _taskIds.remove(key);
  }

  Future<void> removeSurah(int number) async {
    await repository.store.deleteSurah(number);
    final root = await getApplicationSupportDirectory();
    final file = File('${root.path}/quranx/quran/surah_$number.json');
    if (await file.exists()) await file.delete();
    notifyListeners();
  }

  Future<void> removeAudio(int number) async {
    final file = audioFile(number);
    if (file != null && await file.exists()) await file.delete();
    await repository.store.preferences.remove('audio_path_$number');
    notifyListeners();
  }

  @override
  void dispose() {
    _updates?.cancel();
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
    this.onLogConsumed,
  });

  final String title;
  final String detail;
  final VoidCallback? onRetry;
  final Future<void> Function()? onLogConsumed;

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
      return;
    }
    if (launched && context.mounted && onLogConsumed != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hapus file log?'),
          content: const Text(
            'GitHub sudah dibuka. Setelah Anda menekan Submit pada GitHub, '
            'kembali ke QuranX lalu konfirmasi untuk menghapus file log ini.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Simpan'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sudah dikirim, hapus'),
            ),
          ],
        ),
      );
      if (confirmed == true) await onLogConsumed!();
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
          if (onLogConsumed != null) await onLogConsumed!();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Full error log disalin dan dihapus.'),
              ),
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

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  List<DiagnosticLogFile> files = const <DiagnosticLogFile>[];
  String directory = 'Menyiapkan folder log...';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final values = await Future.wait([
      DiagnosticFileStore.list(),
      DiagnosticFileStore.directoryDescription(),
    ]);
    if (!mounted) return;
    setState(() {
      files = values[0] as List<DiagnosticLogFile>;
      directory = values[1] as String;
      loading = false;
    });
  }

  Future<void> _deleteAll() async {
    if (files.isEmpty || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus semua file log?'),
        content: Text(
          'Sebanyak ${files.length} file log akan dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus semua'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DiagnosticLog.clearAll();
    await _refresh();
  }

  Future<void> _deleteOne(DiagnosticLogFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus file log?'),
        content: Text(file.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DiagnosticLog.deleteFile(file.name);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Log kesalahan'),
      actions: [
        IconButton(
          tooltip: 'Hapus semua file log',
          onPressed: files.isEmpty ? null : _deleteAll,
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ErrorDetailsView(
            title: 'Diagnostik sesi QuranX',
            detail: DiagnosticLog.all,
            onLogConsumed: DiagnosticLog.clearAll,
          ),
          const Divider(height: 28),
          Text(
            'File log tersimpan',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Folder: $directory',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (files.isEmpty)
            const Text('Belum ada file log yang tersimpan.')
          else
            ...files.map(
              (file) => Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(file.name),
                  subtitle: Text(file.displayPath),
                  trailing: IconButton(
                    tooltip: 'Hapus file log',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteOne(file),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({
    super.key,
    required this.repository,
    required this.audio,
    required this.downloads,
  });
  final QuranRepository repository;
  final AudioController audio;
  final BackgroundDownloadCoordinator downloads;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late final BackgroundDownloadCoordinator manager;
  final Set<int> selected = <int>{};
  bool loading = false;
  String? message;

  @override
  void initState() {
    super.initState();
    manager = widget.downloads..addListener(_refresh);
  }

  @override
  void dispose() {
    manager.removeListener(_refresh);
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

  Future<void> _confirmDelete(int number, {required bool audio}) async {
    final label = audio ? 'audio' : 'data Quran';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hapus $label?'),
        content: Text(
          'File $label untuk surah nomor $number akan dihapus dari penyimpanan offline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (audio) {
        await manager.removeAudio(number);
      } else {
        await manager.removeSurah(number);
      }
      if (mounted) {
        setState(() => message = '$label surah $number berhasil dihapus.');
      }
    } catch (error, stack) {
      if (mounted) {
        setState(
          () => message = DiagnosticLog.record(
            error,
            stack,
            context: 'downloads.delete.${audio ? 'audio' : 'quran'}.$number',
          ),
        );
      }
    }
  }

  Future<void> _cancel(int number, {required bool audio}) async {
    try {
      await manager.cancel(number, audio: audio);
    } catch (error, stack) {
      if (mounted) {
        setState(
          () => message = DiagnosticLog.record(
            error,
            stack,
            context: 'downloads.cancel.${audio ? 'audio' : 'quran'}.$number',
          ),
        );
      }
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
              onLogConsumed: () => DiagnosticLog.deleteForDetail(message!),
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
              final quranProgress = manager.progress['quran:${summary.number}'];
              final audioProgress = manager.progress['audio:${summary.number}'];
              final quranRunning = quranProgress != null && quranProgress < 1;
              final audioRunning = audioProgress != null && audioProgress < 1;
              return CheckboxListTile(
                value: selected.contains(summary.number),
                onChanged: (value) => setState(() {
                  value == true
                      ? selected.add(summary.number)
                      : selected.remove(summary.number);
                }),
                title: Text('${summary.number}. ${summary.name}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${quranReady ? 'Quran tersedia' : 'Quran belum diunduh'} • ${audioReady ? 'audio tersedia' : 'audio belum diunduh'}',
                    ),
                    if (quranRunning) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: quranProgress),
                      Text('Quran ${(quranProgress * 100).round()}%'),
                    ],
                    if (audioRunning) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: audioProgress),
                      Text('Audio ${(audioProgress * 100).round()}%'),
                    ],
                  ],
                ),
                secondary: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      quranReady && audioReady
                          ? Icons.download_done
                          : Icons.cloud_download_outlined,
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Kelola unduhan',
                      onSelected: (action) {
                        switch (action) {
                          case 'delete_quran':
                            _confirmDelete(summary.number, audio: false);
                          case 'delete_audio':
                            _confirmDelete(summary.number, audio: true);
                          case 'cancel_quran':
                            _cancel(summary.number, audio: false);
                          case 'cancel_audio':
                            _cancel(summary.number, audio: true);
                        }
                      },
                      itemBuilder: (context) => [
                        if (quranReady)
                          const PopupMenuItem(
                            value: 'delete_quran',
                            child: Text('Hapus Quran'),
                          ),
                        if (audioReady)
                          const PopupMenuItem(
                            value: 'delete_audio',
                            child: Text('Hapus audio'),
                          ),
                        if (quranRunning)
                          const PopupMenuItem(
                            value: 'cancel_quran',
                            child: Text('Batalkan unduh Quran'),
                          ),
                        if (audioRunning)
                          const PopupMenuItem(
                            value: 'cancel_audio',
                            child: Text('Batalkan unduh audio'),
                          ),
                      ],
                    ),
                  ],
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
  const SearchScreen({super.key, required this.repository, this.network});
  final QuranRepository repository;
  final NetworkMonitor? network;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();

  bool get networkIsAvailable => widget.network?.online ?? true;
  late final AudioController audio;
  Timer? _debounce;
  int _queryGeneration = 0;
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
    _debounce?.cancel();
    controller.dispose();
    audio.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final generation = ++_queryGeneration;
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        results = <Map<String, dynamic>>[];
        error = null;
        loading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _search(query: query, generation: generation);
    });
  }

  Future<void> _search({String? query, int? generation}) async {
    final normalized = (query ?? controller.text).trim();
    final requestGeneration = generation ?? ++_queryGeneration;
    if (normalized.isEmpty) {
      if (!mounted || requestGeneration != _queryGeneration) return;
      setState(() {
        results = <Map<String, dynamic>>[];
        error = null;
        loading = false;
      });
      return;
    }
    if (mounted && requestGeneration == _queryGeneration) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      var nextResults = <Map<String, dynamic>>[];
      String? nextError;
      if (mode == 'juz') {
        final juz = int.tryParse(normalized);
        if (juz == null || juz < 1 || juz > 30) {
          throw const FormatException('Nomor Juz harus 1 sampai 30.');
        }
        nextResults = widget.repository.searchJuz(juz);
        if (nextResults.isEmpty) {
          nextError = 'Metadata Juz belum tersedia pada data yang tersimpan.';
        }
      } else {
        nextResults = widget.repository.searchSurah(normalized);
        if (nextResults.isEmpty && networkIsAvailable) {
          nextResults = await widget.repository.api.search(normalized);
        }
        if (nextResults.isEmpty) nextError = 'Surah tidak ditemukan.';
      }
      if (!mounted || requestGeneration != _queryGeneration) return;
      setState(() {
        results = nextResults;
        error = nextError;
        loading = false;
      });
    } catch (value, stack) {
      if (!mounted || requestGeneration != _queryGeneration) return;
      setState(() {
        error = DiagnosticLog.record(value, stack, context: 'search.$mode');
        loading = false;
      });
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
            onSelectionChanged: (value) {
              setState(() {
                mode = value.first;
                results = <Map<String, dynamic>>[];
                error = null;
              });
              _onQueryChanged(controller.text);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
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

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key, required this.repository});

  final QuranRepository repository;

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  final cityController = TextEditingController();
  final api = PrayerApiClient();
  late final PrayerReminderService reminders;
  Timer? _debounce;
  int _generation = 0;
  List<PrayerCity> cities = <PrayerCity>[];
  PrayerCity? selectedCity;
  PrayerSchedule? schedule;
  String? error;
  bool loading = false;
  bool scheduling = false;

  @override
  void initState() {
    super.initState();
    reminders = PrayerReminderService(widget.repository.store.preferences);
    reminders.initialize();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    cityController.dispose();
    api.dispose();
    super.dispose();
  }

  void _onCityChanged(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        cities = <PrayerCity>[];
        error = null;
        loading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await api.searchCities(query);
        if (!mounted || generation != _generation) return;
        setState(() {
          cities = results;
          loading = false;
          error = results.isEmpty ? 'Wilayah tidak ditemukan.' : null;
        });
      } catch (value, stack) {
        if (!mounted || generation != _generation) return;
        setState(() {
          loading = false;
          error = DiagnosticLog.record(value, stack, context: 'prayer.cities');
        });
      }
    });
  }

  Future<void> _selectCity(PrayerCity city) async {
    final cityId = int.tryParse(city.id);
    if (cityId == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      selectedCity = city;
      cities = <PrayerCity>[];
      loading = true;
      error = null;
      schedule = null;
    });
    try {
      final loaded = await api.fetchSchedule(cityId, DateTime.now());
      if (!mounted) return;
      setState(() {
        schedule = loaded;
        loading = false;
      });
    } catch (value, stack) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = DiagnosticLog.record(
          value,
          stack,
          context: 'prayer.schedule.$cityId',
        );
      });
    }
  }

  Future<void> _scheduleReminders() async {
    final value = schedule;
    if (value == null) return;
    setState(() => scheduling = true);
    try {
      await reminders.scheduleSevenDays(api, value.cityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifikasi Subuh, Dzuhur, Ashar, Maghrib, dan Isya dijadwalkan.',
            ),
          ),
        );
      }
    } catch (value, stack) {
      if (mounted) {
        setState(
          () => error = DiagnosticLog.record(
            value,
            stack,
            context: 'prayer.schedule_notifications',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => scheduling = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Jadwal Sholat')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Cari kota atau kabupaten dari data live Kemenag RI pada API QuranX.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cityController,
          onChanged: _onCityChanged,
          decoration: InputDecoration(
            labelText: 'Kota / kabupaten',
            hintText: 'Contoh: Bandung',
            prefixIcon: const Icon(Icons.location_city),
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
          ),
        ),
        if (cities.isNotEmpty)
          Card(
            child: Column(
              children: cities
                  .map(
                    (city) => ListTile(
                      title: Text(city.name),
                      subtitle: Text('ID wilayah: ${city.id}'),
                      onTap: () => _selectCity(city),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (selectedCity != null) ...[
          const SizedBox(height: 20),
          Text(
            selectedCity!.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (schedule != null) ...[
            Text(
              '${schedule!.regionName} • ${schedule!.date.toIso8601String().substring(0, 10)}',
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: const [
                  'subuh',
                  'dzuhur',
                  'ashar',
                  'maghrib',
                  'isya',
                ].map((name) => _PrayerTimeRow(name: name)).toList(),
              ),
            ),
            FilledButton.icon(
              onPressed: scheduling ? null : _scheduleReminders,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(
                scheduling ? 'Menjadwalkan…' : 'Aktifkan notifikasi sholat',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Suara adzan pilihan belum ditampilkan karena API yang sama belum menyediakan katalog audio adzan terverifikasi.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ],
    ),
  );
}

class _PrayerTimeRow extends StatelessWidget {
  const _PrayerTimeRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_PrayerSettingsScreenState>();
    final time = state?.schedule?.times[name] ?? '--:--';
    return ListTile(
      leading: const Icon(Icons.access_time),
      title: Text(PrayerReminderService._displayName(name)),
      trailing: Text(time, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

Color _tajwidColor(int index, ColorScheme colors) {
  const palette = <Color>[
    Color(0xff0f766e),
    Color(0xff2563eb),
    Color(0xffb45309),
    Color(0xffbe123c),
    Color(0xff7c3aed),
    Color(0xff15803d),
  ];
  final base = palette[index % palette.length];
  return Color.lerp(
    base,
    colors.surface,
    colors.brightness == Brightness.dark ? 0.15 : 0.0,
  )!;
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
      final colors = Theme.of(context).colorScheme;
      return Card(
        color: colors.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tajwid Mode berwarna',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('API mendeteksi ${data.totalRules} kelompok aturan.'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var index = 0; index < data.rules.length; index++)
                    Chip(
                      avatar: CircleAvatar(
                        backgroundColor: _tajwidColor(index, colors),
                        radius: 7,
                      ),
                      label: Text(data.rules[index]),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Warna menandai kelompok aturan yang dikembalikan API. '
                'API saat ini belum memberikan rentang karakter untuk mewarnai setiap huruf Arab.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (data.guidance.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(data.guidance),
              ],
            ],
          ),
        ),
      );
    },
  );
}
