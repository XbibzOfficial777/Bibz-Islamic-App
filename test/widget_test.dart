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

  test('prayer schedule validates live city and requested date', () {
    final schedule = PrayerSchedule.fromApi(
      {
        'success': true,
        'data': {
          'isLiveDataFromInternet': true,
          'source': 'Kementerian Agama Republik Indonesia (Kemenag RI)',
          'cityInfo': {
            'id': 1219,
            'lokasi': 'KOTA BANDUNG',
            'daerah': 'JAWA BARAT',
          },
          'schedule': {
            'date': '2026-08-24',
            'tanggal': 'Senin, 24/08/2026',
            'imsak': '04:28',
            'subuh': '04:38',
            'terbit': '05:47',
            'dhuha': '06:19',
            'dzuhur': '11:56',
            'ashar': '15:15',
            'maghrib': '17:57',
            'isya': '19:03',
          },
        },
      },
      requestedCityId: 1219,
      requestedDate: DateTime(2026, 8, 24),
    );
    expect(schedule.cityName, 'KOTA BANDUNG');
    expect(schedule.times['ashar'], '15:15');
  });

  test('prayer schedule rejects an astronomical fallback response', () {
    expect(
      () => PrayerSchedule.fromApi(
        {
          'success': true,
          'data': {
            'isLiveDataFromInternet': false,
            'astronomicalData': {
              'times': {'fajr': '21.39.00'},
            },
          },
        },
        requestedCityId: 1219,
        requestedDate: DateTime(2026, 8, 24),
      ),
      throwsFormatException,
    );
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
    expect(
      DiagnosticLog.fileNameFor(detail),
      matches(RegExp(r'^QuranX_Log_\d{8}_\d{6}_\d{6}\.txt$')),
    );
  });

  test('diagnostic log persists info and warning levels', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await DiagnosticLog.initialize(preferences);
    final info = DiagnosticLog.recordInfo(
      'Flutter informational event',
      context: 'test.info',
    );
    final warning = DiagnosticLog.recordWarning(
      'Flutter warning event',
      context: 'test.warning',
      stack: StackTrace.current,
    );
    await Future<void>.delayed(Duration.zero);
    expect(info, contains('level: info'));
    expect(warning, contains('level: warning'));
    expect(warning, contains('stackTrace:'));
    expect(preferences.getStringList('diagnostic_log'), contains(info));
    expect(preferences.getStringList('diagnostic_log'), contains(warning));
  });

  testWidgets('diagnostics screen renders the current log and actions', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await DiagnosticLog.initialize(preferences);
    DiagnosticLog.recordWarning(
      'visible diagnostics warning',
      context: 'test.screen',
    );
    await tester.pumpWidget(const MaterialApp(home: DiagnosticsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('visible diagnostics warning'), findsOneWidget);
    expect(find.text('Copy Full Error Log'), findsOneWidget);
    expect(find.text('Report Issue'), findsOneWidget);
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
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Copy Full Error Log'), findsOneWidget);
    expect(find.text('Report Issue'), findsOneWidget);
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
