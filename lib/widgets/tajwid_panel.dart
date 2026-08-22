part of '../main.dart';

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
