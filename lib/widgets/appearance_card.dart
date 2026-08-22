part of '../main.dart';

class AppearanceSettingsCard extends StatelessWidget {
  const AppearanceSettingsCard({
    super.key,
    required this.appearance,
    required this.onChanged,
  });
  final QuranXAppearance appearance;
  final Future<void> Function(QuranXAppearance) onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tampilan & bacaan',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          DropdownButtonFormField<AppThemePreference>(
            initialValue: appearance.themePreference,
            decoration: const InputDecoration(labelText: 'Tema'),
            items: const [
              DropdownMenuItem(
                value: AppThemePreference.system,
                child: Text('Sistem'),
              ),
              DropdownMenuItem(
                value: AppThemePreference.light,
                child: Text('Light'),
              ),
              DropdownMenuItem(
                value: AppThemePreference.dark,
                child: Text('Dark'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(appearance.copyWith(themePreference: value));
              }
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: appearance.colorPreset,
            decoration: const InputDecoration(labelText: 'Warna aksen'),
            items: const [
              DropdownMenuItem(value: 'emerald', child: Text('Emerald')),
              DropdownMenuItem(value: 'navy', child: Text('Navy')),
              DropdownMenuItem(value: 'amber', child: Text('Amber')),
              DropdownMenuItem(value: 'rose', child: Text('Rose')),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(appearance.copyWith(colorPreset: value));
              }
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: appearance.fontFamily,
            decoration: const InputDecoration(labelText: 'Font antarmuka'),
            items: const [
              DropdownMenuItem(value: 'system', child: Text('System Sans')),
              DropdownMenuItem(value: 'serif', child: Text('Serif')),
              DropdownMenuItem(value: 'mono', child: Text('Monospace')),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(appearance.copyWith(fontFamily: value));
              }
            },
          ),
          const SizedBox(height: 8),
          Text('Ukuran teks: ${(appearance.textScale * 100).round()}%'),
          Slider(
            value: appearance.textScale,
            min: 0.85,
            max: 1.45,
            divisions: 12,
            label: '${(appearance.textScale * 100).round()}%',
            onChanged: (value) =>
                onChanged(appearance.copyWith(textScale: value)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tampilkan transliterasi'),
            value: appearance.showTransliteration,
            onChanged: (value) =>
                onChanged(appearance.copyWith(showTransliteration: value)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tampilkan terjemahan'),
            value: appearance.showTranslation,
            onChanged: (value) =>
                onChanged(appearance.copyWith(showTranslation: value)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tajwid Mode'),
            subtitle: const Text(
              'Menampilkan panel analisis tajwid yang tersedia dari API.',
            ),
            value: appearance.tajwidMode,
            onChanged: (value) =>
                onChanged(appearance.copyWith(tajwidMode: value)),
          ),
        ],
      ),
    ),
  );
}
