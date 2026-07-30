import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_config.dart';
import '../api/token_storage.dart';

class AppErrorReporter {
  AppErrorReporter._();

  static final AppErrorReporter instance = AppErrorReporter._();
  static const _queueKey = 'app_error_report_queue_v1';
  static const _reportPath = '/client-errors/';
  static const _maxQueueSize = 20;
  static const _maxReportsPerMinute = 10;

  final Map<String, DateTime> _recent = {};
  final List<DateTime> _sentAt = [];
  bool _sending = false;

  Future<void> initialize() async {
    await flush();
  }

  Future<void> report(
    Object error,
    StackTrace? stack, {
    String source = 'flutter',
    String location = '',
    String severity = 'error',
    int? statusCode,
    Map<String, Object?> context = const {},
  }) async {
    if (isReportingLocation(location)) return;
    final message = sanitize(error.toString(), limit: 500);
    final exceptionType = error.runtimeType.toString();
    final fingerprint = '$exceptionType|$location|$message';
    final now = DateTime.now();

    if (!registerFingerprint(fingerprint, now)) return;

    final payload = <String, Object?>{
      'source': source,
      'severity': severity,
      'message': message,
      'exceptionType': sanitize(exceptionType, limit: 120),
      'location': sanitize(location, limit: 300),
      'statusCode': statusCode,
      'stackTrace': sanitize(stack?.toString() ?? '', limit: 4000),
      'context': sanitizeMap(context),
      'platform': defaultTargetPlatform.name,
      'releaseMode': kReleaseMode,
    };
    _sentAt.add(now);
    if (!await _send(payload)) await _enqueue(payload);
  }

  Future<void> flush() async {
    if (_sending) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_queueKey) ?? const [];
    if (encoded.isEmpty) return;
    final remaining = <String>[];
    for (final item in encoded) {
      try {
        final payload = jsonDecode(item);
        if (payload is! Map<String, dynamic> || !await _send(payload)) {
          remaining.add(item);
        }
      } catch (_) {
        // Discard malformed local reports.
      }
    }
    await prefs.setStringList(_queueKey, remaining.take(_maxQueueSize).toList());
  }

  Future<bool> _send(Map<String, Object?> payload) async {
    if (_sending) return false;
    _sending = true;
    try {
      final token = await TokenStorage.getAccessToken();
      final base = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await http
          .post(
            Uri.parse('$base$_reportPath'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      _sending = false;
    }
  }

  Future<void> _enqueue(Map<String, Object?> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = [...?prefs.getStringList(_queueKey), jsonEncode(payload)];
    final bounded = queue.length > _maxQueueSize
        ? queue.sublist(queue.length - _maxQueueSize)
        : queue;
    await prefs.setStringList(_queueKey, bounded);
  }

  static Map<String, Object?> sanitizeMap(Map<String, Object?> value) {
    final result = <String, Object?>{};
    for (final entry in value.entries.take(30)) {
      final key = entry.key.toLowerCase();
      if (key.contains('token') ||
          key.contains('password') ||
          key.contains('secret') ||
          key.contains('otp') ||
          key.contains('authorization') ||
          key.contains('account') ||
          key.contains('aadhaar') ||
          key.contains('pan')) {
        result[entry.key] = '[redacted]';
      } else {
        result[entry.key] = sanitize(entry.value.toString(), limit: 500);
      }
    }
    return result;
  }

  @visibleForTesting
  static bool isReportingLocation(String location) => location.contains(_reportPath);

  @visibleForTesting
  bool registerFingerprint(String fingerprint, DateTime now) {
    _recent.removeWhere((_, seen) => now.difference(seen) > const Duration(minutes: 5));
    final seen = _recent[fingerprint];
    if (seen != null && now.difference(seen) < const Duration(minutes: 1)) {
      return false;
    }
    _recent[fingerprint] = now;
    _sentAt.removeWhere((sent) => now.difference(sent) > const Duration(minutes: 1));
    return _sentAt.length < _maxReportsPerMinute;
  }

  static String sanitize(String value, {int limit = 1000}) {
    var cleaned = value
        .replaceAll(
          RegExp(r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', caseSensitive: false),
          '[email]',
        )
        .replaceAll(RegExp(r'(?<!\d)(?:\+?91[- ]?)?[6-9]\d{9}(?!\d)'), '[phone]')
        .replaceAll(RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b', caseSensitive: false), '[pan]')
        .replaceAll(RegExp(r'(?<!\d)\d{12}(?!\d)'), '[number]');
    if (cleaned.length > limit) cleaned = cleaned.substring(0, limit);
    return cleaned;
  }
}
