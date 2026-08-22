part of '../main.dart';

class JuzRange {
  const JuzRange(this.startSurah, this.startAyah, this.endSurah, this.endAyah);
  final int startSurah;
  final int startAyah;
  final int endSurah;
  final int endAyah;
}

const canonicalJuzRanges = <JuzRange>[
  JuzRange(1, 1, 2, 141),
  JuzRange(2, 142, 2, 252),
  JuzRange(2, 253, 3, 92),
  JuzRange(3, 93, 4, 23),
  JuzRange(4, 24, 4, 147),
  JuzRange(4, 148, 5, 81),
  JuzRange(5, 82, 6, 110),
  JuzRange(6, 111, 7, 87),
  JuzRange(7, 88, 8, 40),
  JuzRange(8, 41, 9, 92),
  JuzRange(9, 93, 11, 5),
  JuzRange(11, 6, 12, 52),
  JuzRange(12, 53, 14, 52),
  JuzRange(15, 1, 16, 128),
  JuzRange(17, 1, 18, 74),
  JuzRange(18, 75, 20, 135),
  JuzRange(21, 1, 23, 118),
  JuzRange(23, 119, 25, 20),
  JuzRange(25, 21, 27, 55),
  JuzRange(27, 56, 29, 45),
  JuzRange(29, 46, 33, 30),
  JuzRange(33, 31, 36, 27),
  JuzRange(36, 28, 39, 31),
  JuzRange(39, 32, 41, 46),
  JuzRange(41, 47, 45, 37),
  JuzRange(45, 38, 51, 30),
  JuzRange(51, 31, 57, 29),
  JuzRange(58, 1, 66, 12),
  JuzRange(66, 13, 72, 28),
  JuzRange(73, 1, 77, 50),
  JuzRange(78, 1, 114, 6),
];

bool _inJuzRange(int surah, int ayah, JuzRange range) {
  final current = surah * 1000 + ayah;
  final start = range.startSurah * 1000 + range.startAyah;
  final end = range.endSurah * 1000 + range.endAyah;
  return current >= start && current <= end;
}
