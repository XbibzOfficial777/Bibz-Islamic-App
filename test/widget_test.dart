import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bibz/main.dart';

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

  testWidgets('Bibz home displays the Quran navigation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = QuranRepository(
      QuranApiClient(),
      LocalStore(preferences),
    );
    await tester.pumpWidget(BibzApp(repository: repository));
    expect(find.text('Bibz Islamic'), findsOneWidget);
    expect(find.text('Surah pilihan'), findsOneWidget);
    expect(find.text('Quran'), findsOneWidget);
  });
}
