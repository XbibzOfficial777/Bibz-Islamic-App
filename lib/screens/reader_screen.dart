part of '../main.dart';

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
