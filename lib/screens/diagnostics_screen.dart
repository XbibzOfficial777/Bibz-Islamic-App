part of '../main.dart';

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
