import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/token_storage.dart';
import '../../../core/services/app_error_reporter.dart';

/// Dio HTTP client for KYC & Payments module.
class KycDioClient {
  KycDioClient._();

  static final KycDioClient instance = KycDioClient._();

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) {
            final authorization = options.headers['Authorization']?.toString();
            final hasBearerToken =
                authorization != null && authorization.startsWith('Bearer ');
            debugPrint(
              '[KYC API] ${options.method} ${options.path} '
              'Authorization: ${hasBearerToken ? 'Bearer present' : 'missing'}',
            );
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final status = error.response?.statusCode ?? 500;
          final data = error.response?.data;
          final message = _extractErrorMessage(
            data,
            _friendlyDioMessage(error),
          );
          final path = error.requestOptions.path;
          if (status != 401 &&
              status != 403 &&
              !path.contains('/client-errors/') &&
              (status >= 500 || error.response == null)) {
            unawaited(
              AppErrorReporter.instance.report(
                ApiException(status, message, code: _extractErrorCode(data)),
                error.stackTrace,
                location: path,
                statusCode: status,
                context: {
                  'transport': 'dio',
                  'method': error.requestOptions.method,
                  'errorType': error.type.name,
                },
              ),
            );
          }
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              error: ApiException(
                status,
                message,
                code: _extractErrorCode(data),
              ),
            ),
          );
        },
      ),
    );

  Dio get dio => _dio;

  static String _extractErrorMessage(dynamic data, String fallback) {
    if (data is! Map) return fallback;

    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }

    final retryAfter = data['retry_after_seconds'];
    if (retryAfter is num && retryAfter > 0) {
      return 'Too many attempts. Try again in ${retryAfter.round()} seconds.';
    }

    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    if (detail is List && detail.isNotEmpty) {
      return detail.map((item) => item.toString()).join('. ');
    }

    for (final entry in data.entries) {
      if (entry.key == 'code') continue;
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        return '${entry.key}: ${value.first}';
      }
    }

    return fallback;
  }

  static String? _extractErrorCode(dynamic data) {
    if (data is! Map) return null;
    final code = data['code'];
    if (code is String && code.trim().isNotEmpty) {
      return code.trim();
    }
    return null;
  }

  static String _friendlyDioMessage(DioException error) {
    final status = error.response?.statusCode;
    if (status == 301 || status == 302 || status == 307 || status == 308) {
      return 'API URL must use HTTPS. Update ApiConfig.baseUrl to https://… '
          '(nginx redirects HTTP with status $status).';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server is taking too long to respond. Check that Django is running at ${ApiConfig.baseUrl}.';
      case DioExceptionType.connectionError:
        return 'Cannot reach server at ${ApiConfig.baseUrl}. Check network and that nginx/gunicorn is running.';
      default:
        return error.message ?? 'Request failed';
    }
  }

  Never _rethrowAsApi(DioException error) {
    if (error.error is ApiException) throw error.error!;
    throw ApiException(
      error.response?.statusCode ?? 500,
      _extractErrorMessage(error.response?.data, _friendlyDioMessage(error)),
    );
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return res.data ?? {};
    } on DioException catch (e) {
      _rethrowAsApi(e);
    }
  }

  Future<Map<String, dynamic>> postJson(String path, {Map<String, dynamic>? body}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      return res.data ?? {};
    } on DioException catch (e) {
      _rethrowAsApi(e);
    }
  }
}

