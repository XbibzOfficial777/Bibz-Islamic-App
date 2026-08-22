part of '../main.dart';

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
