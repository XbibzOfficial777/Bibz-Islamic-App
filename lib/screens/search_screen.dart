part of '../main.dart';

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
