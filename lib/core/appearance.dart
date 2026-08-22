part of '../main.dart';

class QuranXAppearance {
  const QuranXAppearance({
    this.themePreference = AppThemePreference.system,
    this.colorPreset = 'emerald',
    this.fontFamily = 'system',
    this.textScale = 1.0,
    this.showTranslation = true,
    this.showTransliteration = true,
    this.tajwidMode = false,
  });

  final AppThemePreference themePreference;
  final String colorPreset;
  final String fontFamily;
  final double textScale;
  final bool showTranslation;
  final bool showTransliteration;
  final bool tajwidMode;

  ThemeMode get themeMode {
    switch (themePreference) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  Color get seedColor {
    switch (colorPreset) {
      case 'navy':
        return const Color(0xff1e40af);
      case 'amber':
        return const Color(0xffb45309);
      case 'rose':
        return const Color(0xffbe123c);
      case 'emerald':
      default:
        return const Color(0xff0e6b55);
    }
  }

  String get resolvedFontFamily {
    switch (fontFamily) {
      case 'serif':
        return 'serif';
      case 'mono':
        return 'monospace';
      case 'system':
      default:
        return 'sans-serif';
    }
  }

  QuranXAppearance copyWith({
    AppThemePreference? themePreference,
    String? colorPreset,
    String? fontFamily,
    double? textScale,
    bool? showTranslation,
    bool? showTransliteration,
    bool? tajwidMode,
  }) => QuranXAppearance(
    themePreference: themePreference ?? this.themePreference,
    colorPreset: colorPreset ?? this.colorPreset,
    fontFamily: fontFamily ?? this.fontFamily,
    textScale: textScale ?? this.textScale,
    showTranslation: showTranslation ?? this.showTranslation,
    showTransliteration: showTransliteration ?? this.showTransliteration,
    tajwidMode: tajwidMode ?? this.tajwidMode,
  );
}

extension AppearanceStore on LocalStore {
  QuranXAppearance appearance() => QuranXAppearance(
    themePreference: themePreference(),
    colorPreset: preferences.getString('color_preset') ?? 'emerald',
    fontFamily: preferences.getString('font_family') ?? 'system',
    textScale: preferences.getDouble('text_scale') ?? 1.0,
    showTranslation: preferences.getBool('show_translation') ?? true,
    showTransliteration: preferences.getBool('show_transliteration') ?? true,
    tajwidMode: preferences.getBool('tajwid_mode') ?? false,
  );

  Future<void> saveAppearance(QuranXAppearance value) async {
    await Future.wait([
      setThemePreference(value.themePreference),
      preferences.setString('color_preset', value.colorPreset),
      preferences.setString('font_family', value.fontFamily),
      preferences.setDouble('text_scale', value.textScale),
      preferences.setBool('show_translation', value.showTranslation),
      preferences.setBool('show_transliteration', value.showTransliteration),
      preferences.setBool('tajwid_mode', value.tajwidMode),
    ]);
  }
}
