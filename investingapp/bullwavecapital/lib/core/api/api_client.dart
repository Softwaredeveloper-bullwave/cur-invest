import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';
import '../services/app_error_reporter.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  String? _accessToken;

  Future<void> setAccessToken(String? token) async {
    _accessToken = token;
  }

  Future<void> loadToken() async {
    _accessToken = await TokenStorage.getAccessToken();
  }

  Map<String, String> _headers({bool auth = true, bool json = true}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) headers['Content-Type'] = 'application/json';
    if (auth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized').replace(queryParameters: query);
  }

  void _report(Object error, StackTrace stack, String path, {int? statusCode}) {
    if (statusCode == 401 || statusCode == 403 || path.contains('/client-errors/')) return;
    unawaited(
      AppErrorReporter.instance.report(
        error,
        stack,
        location: path,
        statusCode: statusCode,
        context: {'transport': 'http'},
      ),
    );
  }

  String _friendlyServerError(int statusCode) {
    if (statusCode >= 500) {
      return 'Server error at ${ApiConfig.baseUrl}. The API responded but failed — '
          'check GET /health/ and backend logs on the server.';
    }
    return 'Unexpected server response. Check backend logs.';
  }

  dynamic _decode(http.Response response, String path) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        final error = ApiException(
          response.statusCode,
          _friendlyServerError(response.statusCode),
        );
        if (response.statusCode >= 500) {
          _report(error, StackTrace.current, path, statusCode: response.statusCode);
        }
        throw error;
      }
    }
    if (response.statusCode >= 400) {
      String message = 'Request failed (${response.statusCode})';
      if (body is Map) {
        final detail = body['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          message = detail.first.toString();
        }
      } else if (response.statusCode >= 500) {
        message = _friendlyServerError(response.statusCode);
      }
      final error = ApiException(response.statusCode, message);
      if (response.statusCode >= 500) {
        _report(error, StackTrace.current, path, statusCode: response.statusCode);
      }
      throw error;
    }
    return body;
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
    Duration? timeout,
  }) async {
    try {
      final response = await http
          .get(
            _uri(path, query),
            headers: _headers(auth: auth),
          )
          .timeout(timeout ?? const Duration(seconds: 20));
      return _decode(response, path);
    } catch (error, stack) {
      if (error is! ApiException) _report(error, stack, path);
      rethrow;
    }
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    Duration? timeout,
  }) async {
    final uri = _uri(path);
    if (kDebugMode) {
      debugPrint('[API] POST ${uri.path}');
    }
    try {
      final response = await http
          .post(
            uri,
            headers: _headers(auth: auth),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout ?? const Duration(seconds: 15));
      if (kDebugMode) {
        debugPrint('[API] ${response.statusCode} ${uri.path}');
      }
      return _decode(response, path);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[API] ERROR POST $uri -> $e');
      }
      if (e is! ApiException) _report(e, stack, path);
      rethrow;
    }
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final response = await http.patch(
        _uri(path),
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      );
      return _decode(response, path);
    } catch (error, stack) {
      if (error is! ApiException) _report(error, stack, path);
      rethrow;
    }
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    try {
      final response = await http.delete(
        _uri(path),
        headers: _headers(auth: auth),
      );
      return _decode(response, path);
    } catch (error, stack) {
      if (error is! ApiException) _report(error, stack, path);
      rethrow;
    }
  }

  Future<dynamic> multipart(
    String path, {
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
    bool auth = true,
    Duration? timeout,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_headers(auth: auth, json: false));
      request.fields.addAll(fields);
      request.files.addAll(files);
      final streamed = await request.send().timeout(timeout ?? const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      return _decode(response, path);
    } catch (error, stack) {
      if (error is! ApiException) _report(error, stack, path);
      rethrow;
    }
  }

  /// POST JSON body and return raw response bytes (e.g. AI TTS audio).
  Future<List<int>> postBytes(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    Duration? timeout,
  }) async {
    try {
      final response = await http
          .post(
            _uri(path),
            headers: _headers(auth: auth),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout ?? const Duration(seconds: 60));

      if (response.statusCode >= 400) {
        String message = 'Request failed (${response.statusCode})';
        if (response.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map) {
              final detail = decoded['detail'];
              if (detail is String && detail.isNotEmpty) message = detail;
            }
          } catch (_) {}
        }
        final error = ApiException(response.statusCode, message);
        if (response.statusCode >= 500) {
          _report(error, StackTrace.current, path, statusCode: response.statusCode);
        }
        throw error;
      }
      return response.bodyBytes;
    } catch (error, stack) {
      if (error is! ApiException) _report(error, stack, path);
      rethrow;
    }
  }
}
