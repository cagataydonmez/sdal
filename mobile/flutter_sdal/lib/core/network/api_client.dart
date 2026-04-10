import 'dart:convert';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import '../config/app_config.dart';
import '../storage/app_support_directory.dart';
import 'api_result.dart';
import 'api_result_parser.dart';

typedef UnauthorizedHandler = void Function();

class ApiClient {
  ApiClient._({
    required this.config,
    required Dio dio,
    required PersistCookieJar cookieJar,
  }) : _dio = dio,
       _cookieJar = cookieJar;

  final AppConfig config;
  final Dio _dio;
  final PersistCookieJar _cookieJar;
  UnauthorizedHandler? onUnauthorized;

  static Future<ApiClient> create(AppConfig config) async {
    final supportDir = await getSdalAppSupportDirectory();
    final cookieDir = Directory('${supportDir.path}/sdal_cookies');
    await cookieDir.create(recursive: true);

    final cookieJar = PersistCookieJar(
      storage: FileStorage(cookieDir.path),
      ignoreExpires: false,
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        responseType: ResponseType.plain,
        headers: const {
          HttpHeaders.acceptHeader: 'application/json, text/plain, */*',
        },
      ),
    );

    dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
        logPrint: (message) => debugPrint(message.toString()),
      ),
    );

    return ApiClient._(config: config, dio: dio, cookieJar: cookieJar);
  }

  Uri buildApiUri(String path, {Map<String, dynamic>? query}) {
    final raw = path.startsWith('http://') || path.startsWith('https://')
        ? Uri.parse(path)
        : config.siteBaseUri.resolve(path.startsWith('/') ? path : '/$path');
    final mergedQuery = {...raw.queryParameters, ..._normalizeQuery(query)};
    return mergedQuery.isEmpty
        ? raw
        : raw.replace(queryParameters: mergedQuery);
  }

  Uri buildWebSocketUri(String path, {Map<String, dynamic>? query}) {
    final site = buildApiUri(path, query: query);
    return site.replace(scheme: site.scheme == 'https' ? 'wss' : 'ws');
  }

  Future<String?> cookieHeaderForUri(Uri uri) async {
    // Cookie jar stores cookies keyed by http/https scheme; remap ws/wss.
    final cookieUri = switch (uri.scheme) {
      'wss' => uri.replace(scheme: 'https'),
      'ws' => uri.replace(scheme: 'http'),
      _ => uri,
    };
    final cookies = await _cookieJar.loadForRequest(cookieUri);
    if (cookies.isEmpty) return null;
    return cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    ApiDecoder<T>? decoder,
  }) {
    return _request<T>('GET', path, query: query, decoder: decoder);
  }

  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    ApiDecoder<T>? decoder,
  }) {
    return _request<T>(
      'POST',
      path,
      body: body,
      query: query,
      decoder: decoder,
    );
  }

  Future<ApiResult<T>> put<T>(
    String path, {
    Object? body,
    ApiDecoder<T>? decoder,
  }) {
    return _request<T>('PUT', path, body: body, decoder: decoder);
  }

  Future<ApiResult<T>> patch<T>(
    String path, {
    Object? body,
    ApiDecoder<T>? decoder,
  }) {
    return _request<T>('PATCH', path, body: body, decoder: decoder);
  }

  Future<ApiResult<T>> delete<T>(
    String path, {
    Object? body,
    ApiDecoder<T>? decoder,
  }) {
    return _request<T>('DELETE', path, body: body, decoder: decoder);
  }

  Future<ApiResult<T>> multipart<T>(
    String path, {
    Map<String, dynamic>? fields,
    required Map<String, File> files,
    ApiDecoder<T>? decoder,
  }) async {
    final formData = FormData();
    for (final entry in (fields ?? const <String, dynamic>{}).entries) {
      if (entry.value == null) continue;
      formData.fields.add(MapEntry(entry.key, entry.value.toString()));
    }
    for (final entry in files.entries) {
      final contentType = _guessMediaType(entry.value.path);
      formData.files.add(
        MapEntry(
          entry.key,
          await MultipartFile.fromFile(
            entry.value.path,
            filename: entry.value.uri.pathSegments.isEmpty
                ? entry.key
                : entry.value.uri.pathSegments.last,
            contentType: contentType,
          ),
        ),
      );
    }
    return _request<T>('POST', path, body: formData, decoder: decoder);
  }

  Future<ApiResult<T>> _request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    ApiDecoder<T>? decoder,
  }) async {
    try {
      final response = await _dio.request<String>(
        path.startsWith('http')
            ? path
            : buildApiUri(path, query: query).toString(),
        data: body is FormData
            ? body
            : body == null
            ? null
            : jsonEncode(body),
        options: Options(
          method: method,
          headers: body is FormData
              ? const <String, dynamic>{}
              : const {HttpHeaders.contentTypeHeader: 'application/json'},
        ),
      );
      return _toApiResult<T>(
        response.statusCode ?? 0,
        response.data,
        decoder: decoder,
      );
    } on DioException catch (error) {
      if (error.response != null) {
        await _handleUnauthorized(
          error.response!.requestOptions,
          error.response!.statusCode ?? 0,
        );
        return _toApiResult<T>(
          error.response?.statusCode ?? 0,
          error.response?.data,
          decoder: decoder,
          okOverride: false,
        );
      }
      return ApiResult<T>(
        ok: false,
        statusCode: 0,
        message: error.message ?? 'İstek tamamlanamadı.',
        code: '',
        data: null,
        rawData: null,
      );
    }
  }

  Future<void> _handleUnauthorized(
    RequestOptions options,
    int statusCode,
  ) async {
    if (options.responseType == ResponseType.stream ||
        options.responseType == ResponseType.bytes) {
      return;
    }
    if (options.method.toUpperCase() == 'OPTIONS') return;
    if (!_shouldHandleUnauthorized(options)) return;
    if (statusCode != 401) return;

    await _cookieJar.deleteAll();
    onUnauthorized?.call();
  }

  bool _shouldHandleUnauthorized(RequestOptions options) {
    final uri = Uri.tryParse(options.path);
    final path =
        (uri?.path.isNotEmpty == true
                ? uri!.path
                : Uri.parse(buildApiUri(options.path).toString()).path)
            .trim();

    if (path.isEmpty) return false;
    if (path == '/api/session' || path == '/api/site-access') return false;
    if (path.startsWith('/api/auth/')) return false;
    if (path.startsWith('/api/admin/')) return false;
    return true;
  }

  ApiResult<T> _toApiResult<T>(
    int statusCode,
    dynamic rawBody, {
    ApiDecoder<T>? decoder,
    bool? okOverride,
  }) {
    return parseApiResult<T>(
      statusCode,
      rawBody,
      decoder: decoder,
      okOverride: okOverride,
    );
  }

  Map<String, String> _normalizeQuery(Map<String, dynamic>? query) {
    if (query == null) return const <String, String>{};
    final out = <String, String>{};
    for (final entry in query.entries) {
      if (entry.value == null) continue;
      final text = entry.value.toString().trim();
      if (text.isEmpty) continue;
      out[entry.key] = text;
    }
    return out;
  }

  MediaType? _guessMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.heic')) return MediaType('image', 'heic');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    return MediaType('image', 'jpeg');
  }
}
