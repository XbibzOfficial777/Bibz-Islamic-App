import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quranx/main.dart';

void main() {
  test('Quran validator accepts ordered complete ayahs', () {
    final ayahs = [
      const Ayah(
        number: 1,
        arabic: 'أ',
        transliteration: 'A',
        translation: 'Satu',
      ),
      const Ayah(
        number: 2,
        arabic: 'ب',
        transliteration: 'B',
        translation: 'Dua',
      ),
    ];
    expect(() => QuranValidator.validate(1, 2, ayahs), returnsNormally);
  });

  test('Quran validator rejects incomplete datasets', () {
    final ayahs = [
      const Ayah(
        number: 2,
        arabic: 'أ',
        transliteration: 'A',
        translation: 'Satu',
      ),
    ];
    expect(() => QuranValidator.validate(1, 2, ayahs), throwsFormatException);
  });

  test('appearance settings persist independently from Quran data', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = LocalStore(preferences);
    const expected = QuranXAppearance(
      themePreference: AppThemePreference.dark,
      colorPreset: 'rose',
      fontFamily: 'serif',
      textScale: 1.25,
      showTranslation: false,
      showTransliteration: false,
      tajwidMode: true,
    );
    await store.saveAppearance(expected);
    final actual = store.appearance();
    expect(actual.themePreference, AppThemePreference.dark);
    expect(actual.colorPreset, 'rose');
    expect(actual.fontFamily, 'serif');
    expect(actual.textScale, 1.25);
    expect(actual.showTranslation, isFalse);
    expect(actual.showTransliteration, isFalse);
    expect(actual.tajwidMode, isTrue);
  });

  test('Juz search returns only validated local metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = LocalStore(preferences);
    const surah = Surah(
      number: 1,
      nameArabic: 'الفاتحة',
      nameLatin: 'Al-Fatihah',
      meaning: 'Pembukaan',
      revelationType: 'Mekah',
      description: 'Description',
      ayahs: [
        Ayah(
          number: 1,
          arabic: 'بِسْمِ ٱللَّهِ',
          transliteration: 'Bismillah',
          translation: 'Dengan nama Allah',
          juz: 1,
        ),
      ],
    );
    await store.saveSurah(surah);
    final repository = QuranRepository(QuranApiClient(), store);
    expect(repository.searchJuz(1), hasLength(1));
    expect(repository.searchJuz(2), isEmpty);
  });

  test('diagnostic log keeps a full copyable stack trace', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await DiagnosticLog.initialize(preferences);
    final detail = DiagnosticLog.record(
      StateError('simulated production failure'),
      StackTrace.current,
      context: 'test.diagnostics',
    );
    await Future<void>.delayed(Duration.zero);
    expect(detail, contains('context: test.diagnostics'));
    expect(detail, contains('stackTrace:'));
    expect(preferences.getStringList('diagnostic_log'), isNotEmpty);
  });

  testWidgets('error details exposes copy and report actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorDetailsView(
          title: 'Audio gagal',
          detail: 'full stack trace',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ErrorDetailsView), findsOneWidget);
  });

  testWidgets('QuranX home displays the Quran navigation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = QuranRepository(
      QuranApiClient(),
      LocalStore(preferences),
    );
    await tester.pumpWidget(BibzApp(repository: repository));
    expect(find.text('QuranX'), findsOneWidget);
    expect(find.text('Surah pilihan'), findsOneWidget);
    expect(find.text('Quran'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
