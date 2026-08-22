part of '../main.dart';

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
  final repository = QuranRepository(QuranApiClient(), LocalStore(preferences));
  final downloads = BackgroundDownloadCoordinator(repository);
  await downloads.initialize();
  runZonedGuarded(
    () => runApp(BibzApp(repository: repository, downloads: downloads)),
    (error, stack) => DiagnosticLog.record(error, stack, context: 'dart.zone'),
  );
}

class BibzApp extends StatefulWidget {
  const BibzApp({super.key, required this.repository, this.downloads});
  final QuranRepository repository;
  final BackgroundDownloadCoordinator? downloads;

  @override
  State<BibzApp> createState() => _BibzAppState();
}

class _BibzAppState extends State<BibzApp> {
  late QuranXAppearance appearance;
  late final AudioController audio;
  late final NetworkMonitor network;
  late final BackgroundDownloadCoordinator downloads;
  late final bool ownsDownloads;

  @override
  void initState() {
    super.initState();
    appearance = widget.repository.store.appearance();
    audio = AudioController();
    network = NetworkMonitor();
    ownsDownloads = widget.downloads == null;
    downloads =
        widget.downloads ?? BackgroundDownloadCoordinator(widget.repository);
  }

  @override
  void dispose() {
    audio.dispose();
    network.dispose();
    if (ownsDownloads) downloads.dispose();
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
      downloads: downloads,
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
    required this.downloads,
  });
  final QuranRepository repository;
  final QuranXAppearance appearance;
  final Future<void> Function(QuranXAppearance) onAppearanceChanged;
  final AudioController audio;
  final NetworkMonitor network;
  final BackgroundDownloadCoordinator downloads;
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
                  builder: (_) => SearchScreen(
                    repository: widget.repository,
                    network: widget.network,
                  ),
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
                    downloads: widget.downloads,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Jadwal Sholat & Pengingat'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PrayerSettingsScreen(repository: widget.repository),
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
              builder: (_) => SearchScreen(
                repository: widget.repository,
                network: widget.network,
              ),
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
                downloads: widget.downloads,
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
