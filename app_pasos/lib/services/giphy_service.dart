import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GiphyService {
  static const _apiKey = String.fromEnvironment('GIPHY_API_KEY', defaultValue: '');
  static const _cachePrefix = 'giphy_url_';
  static const _failedPrefix = 'giphy_failed_';

  static bool get hasApiKey => _apiKey.isNotEmpty;

  static Future<String?> searchGif(String query) async {
    if (!hasApiKey) return null;

    final cleanQuery = query
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\sáéíóúñ]'), '')
        .trim();

    if (cleanQuery.isEmpty) return null;

    try {
      final uri = Uri.parse('https://api.giphy.com/v1/gifs/search').replace(queryParameters: {
        'api_key': _apiKey,
        'q': '$cleanQuery exercise',
        'limit': '1',
        'rating': 'g',
        'lang': 'en',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final results = data['data'] as List?;
      if (results == null || results.isEmpty) return null;

      final images = results[0]['images'] as Map<String, dynamic>?;
      if (images == null) return null;

      final preview = images['fixed_height_small'] as Map<String, dynamic>?;
      final full = images['original'] as Map<String, dynamic>?;
      final gifUrl = preview?['url'] as String? ?? full?['url'] as String?;

      return gifUrl;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getCachedOrSearch(String exerciseId, String exerciseName) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix$exerciseId';

    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) return cached;

    final failed = prefs.getString('$_failedPrefix$exerciseId');
    if (failed != null) return null;

    final gifUrl = await searchGif(exerciseName);
    if (gifUrl != null && gifUrl.isNotEmpty) {
      await prefs.setString(cacheKey, gifUrl);
      return gifUrl;
    } else {
      await prefs.setString('$_failedPrefix$exerciseId', '1');
      return null;
    }
  }
}
