part of '../main.dart';

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
