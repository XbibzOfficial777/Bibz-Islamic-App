part of '../main.dart';

class TajwidResult {
  const TajwidResult({
    required this.originalText,
    required this.totalRules,
    required this.rules,
    required this.guidance,
  });

  final String originalText;
  final int totalRules;
  final List<String> rules;
  final String guidance;

  factory TajwidResult.fromJson(Map<String, dynamic> json) {
    final rawRules = (json['rulesDetected'] as List? ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .map((item) => item['ruleName'] as String? ?? 'Aturan tidak bernama')
        .toList();
    return TajwidResult(
      originalText: json['originalText'] as String? ?? '',
      totalRules: json['totalRulesDetected'] as int? ?? rawRules.length,
      rules: rawRules,
      guidance: json['recitationGuidance'] as String? ?? '',
    );
  }
}

class TajwidService {
  TajwidService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<TajwidResult> analyze(String text) async {
    final response = await _client
        .get(Uri.parse('$apiBaseUrl/quran/tajwid'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException('Analisis Tajwid gagal: HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw ApiException(body['message'] as String? ?? 'Analisis Tajwid gagal');
    }
    final result = TajwidResult.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
    if (result.originalText.isEmpty) {
      throw const FormatException('Respons Tajwid tidak memiliki teks sumber');
    }
    return result;
  }
}
