part of '../main.dart';

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
