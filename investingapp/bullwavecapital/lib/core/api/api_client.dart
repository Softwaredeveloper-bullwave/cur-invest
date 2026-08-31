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
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  Future<void> setAccessToken(String? token) async {
    _accessToken = token;
  }

  Future<void> loadToken() async {
    _accessToken = await TokenStorage.getAccessToken();
  }

  Future<Map<String, String>> _headers({bool auth = true, bool json = true}) async {
    if (auth && (_accessToken == null || _accessToken!.isEmpty)) {
      _accessToken = await TokenStorage.getAccessToken();
    }
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) headers['Content-Type'] = 'application/json';
    if (auth && _accessToken != null && _accessToken!.isNotEmpty) {
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

  Future<bool> refreshAccessToken() async {
    if (_isRefreshing && _refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();
    try {
      final refresh = await TokenStorage.getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final response = await http
          .post(
            _uri('/auth/token/refresh/'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final access = body['access'] as String?;
      if (access == null || access.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final rotatedRefresh = body['refresh'] as String? ?? refresh;
      await TokenStorage.saveTokens(access: access, refresh: rotatedRefresh);
      _accessToken = access;
      _refreshCompleter!.complete(true);
      return true;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  void _report(Object error, StackTrace stack, String path, {int? statusCode}) {
    if (statusCode == 401 ||
        statusCode == 403 ||
        path.contains('/client-errors/'))
      return;
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

  String _friendlyServerError(int statusCode, [dynamic body]) {
    if (body is Map) {
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }
    if (statusCode == 404) {
      return 'This market API is not available on the live server yet. '
          'Deploy the latest backend and run migrate, or the app will use a live fallback.';
    }
    if (statusCode == 503) {
      return 'Login is temporarily unavailable. Please try again in a moment.';
    }
    if (statusCode >= 500) {
      return 'Login is temporarily unavailable. Please try again in a moment.';
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
          _friendlyServerError(response.statusCode, body),
        );
        if (response.statusCode >= 500) {
          _report(
            error,
            StackTrace.current,
            path,
            statusCode: response.statusCode,
          );
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
        message = _friendlyServerError(response.statusCode, body);
      }
      final error = ApiException(response.statusCode, message);
      if (response.statusCode >= 500) {
        _report(
          error,
          StackTrace.current,
          path,
          statusCode: response.statusCode,
        );
      }
      throw error;
    }
    return body;
  }

  Future<dynamic> _request(
    Future<http.Response> Function(Map<String, String> headers) send,
    String path, {
    bool auth = true,
    bool json = true,
    Duration? timeout,
  }) async {
    try {
      var headers = await _headers(auth: auth, json: json);
      var response = await send(headers).timeout(
        timeout ?? const Duration(seconds: 20),
      );

      if (auth && response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          headers = await _headers(auth: auth, json: json);
          response = await send(headers).timeout(
            timeout ?? const Duration(seconds: 20),
          );
        }
      }

      return _decode(response, path);
    } catch (error, stack) {
      if (error is! ApiException) _report(error, stack, path);
      rethrow;
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
    Duration? timeout,
  }) async {
    return _request(
      (headers) => http.get(_uri(path, query), headers: headers),
      path,
      auth: auth,
      timeout: timeout,
    );
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
    final result = await _request(
      (headers) => http.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      path,
      auth: auth,
      timeout: timeout ?? const Duration(seconds: 15),
    );
    if (kDebugMode) {
      debugPrint('[API] OK ${uri.path}');
    }
    return result;
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    Duration? timeout,
  }) async {
    return _request(
      (headers) => http.patch(
        _uri(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      path,
      auth: auth,
      timeout: timeout ?? const Duration(seconds: 20),
    );
  }

  Future<dynamic> delete(
    String path, {
    bool auth = true,
    Duration? timeout,
  }) async {
    return _request(
      (headers) => http.delete(_uri(path), headers: headers),
      path,
      auth: auth,
      timeout: timeout ?? const Duration(seconds: 20),
    );
  }

  Future<dynamic> multipart(
    String path, {
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
    bool auth = true,
    Duration? timeout,
  }) async {
    try {
      Future<http.StreamedResponse> send(Map<String, String> headers) async {
        final request = http.MultipartRequest('POST', _uri(path));
        request.headers.addAll(headers);
        request.fields.addAll(fields);
        request.files.addAll(files);
        return request.send();
      }

      var headers = await _headers(auth: auth, json: false);
      var streamed = await send(headers).timeout(
        timeout ?? const Duration(seconds: 60),
      );
      var response = await http.Response.fromStream(streamed);

      if (auth && response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          headers = await _headers(auth: auth, json: false);
          streamed = await send(headers).timeout(
            timeout ?? const Duration(seconds: 60),
          );
          response = await http.Response.fromStream(streamed);
        }
      }

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
      Future<http.Response> send(Map<String, String> headers) => http.post(
        _uri(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );

      var headers = await _headers(auth: auth, json: true);
      var response = await send(headers).timeout(
        timeout ?? const Duration(seconds: 60),
      );

      if (auth && response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          headers = await _headers(auth: auth, json: true);
          response = await send(headers).timeout(
            timeout ?? const Duration(seconds: 60),
          );
        }
      }

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
          _report(
            error,
            StackTrace.current,
            path,
            statusCode: response.statusCode,
          );
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
