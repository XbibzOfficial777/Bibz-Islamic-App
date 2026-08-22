part of '../main.dart';

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
