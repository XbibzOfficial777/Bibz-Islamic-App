part of '../main.dart';

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
