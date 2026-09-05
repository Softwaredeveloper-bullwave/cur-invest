import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/forex_models.dart';

/// Live FX headlines used when Django `/forex/news/` is empty on the server.
class ForexNewsFallback {
  ForexNewsFallback._();

  static const categories = [
    'All',
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'INR',
    'Majors',
    'Central Banks',
    'Market Analysis',
  ];

  static const _feeds = [
    'https://www.fxstreet.com/rss/news',
    'https://news.google.com/rss/search?q=forex+OR+EURUSD+OR+USDJPY&hl=en-US&gl=US&ceid=US:en',
  ];

  static Future<List<ForexNewsModel>> load() async {
    final byId = <String, ForexNewsModel>{};
    await Future.wait(_feeds.map((feed) async {
      try {
        final uri = Uri.https('api.rss2json.com', '/v1/api.json', {
          'rss_url': feed,
        });
        final response = await http.get(uri).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) return;
        final payload = jsonDecode(response.body);
        if (payload is! Map || payload['status'] != 'ok') return;
        final items = payload['items'];
        if (items is! List) return;
        for (final raw in items) {
          if (raw is! Map) continue;
          final title = _clean(raw['title']?.toString() ?? '');
          if (title.isEmpty) continue;
          final link = (raw['link'] ?? raw['guid'] ?? '').toString();
          final id = (raw['guid'] ?? link ?? title).toString();
          final enclosure = raw['enclosure'];
          var image = '';
          if (enclosure is Map) {
            image = (enclosure['link'] ?? '').toString();
          }
          if (image.isEmpty) {
            image = (raw['thumbnail'] ?? '').toString();
          }
          byId[id] = ForexNewsModel(
            id: id,
            title: title,
            summary: _clean(raw['description']?.toString() ?? ''),
            imageUrl: image,
            source: _sourceFor(feed, raw['author']?.toString() ?? ''),
            publishedAt: DateTime.tryParse(raw['pubDate']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
            category: _categoryFor(title, raw['description']?.toString() ?? ''),
            externalUrl: link,
          );
        }
      } catch (_) {}
    }));
    final articles = byId.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return articles.take(40).toList();
  }

  static String _clean(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _sourceFor(String feed, String author) {
    if (feed.contains('fxstreet')) return 'FXStreet';
    if (feed.contains('google')) return author.isEmpty ? 'Google News' : author;
    return author.isEmpty ? 'Forex' : author;
  }

  static String _categoryFor(String title, String summary) {
    final text = '$title $summary'.toLowerCase();
    const rules = <String, List<String>>{
      'Central Banks': ['fed', 'ecb', 'boe', 'boj', 'rbi', 'fomc', 'interest rate'],
      'USD': ['dollar', 'usd', 'greenback', 'dxy'],
      'EUR': ['euro', 'eur'],
      'GBP': ['pound', 'sterling', 'gbp'],
      'JPY': ['yen', 'jpy'],
      'INR': ['rupee', 'inr'],
      'Majors': ['eurusd', 'gbpusd', 'usdjpy', 'eur/usd', 'gbp/usd', 'usd/jpy'],
    };
    for (final entry in rules.entries) {
      if (entry.value.any(text.contains)) return entry.key;
    }
    return 'Market Analysis';
  }
}
