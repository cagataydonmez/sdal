import 'dart:convert';

import 'api_result.dart';
import 'json_utils.dart';

typedef ApiDecoder<T> = T Function(dynamic raw);

ApiResult<T> parseApiResult<T>(
  int statusCode,
  dynamic rawBody, {
  ApiDecoder<T>? decoder,
  bool? okOverride,
}) {
  final parsedBody = parseApiBody(rawBody);
  final payload = parsedBody is Map<String, dynamic> ? parsedBody : parsedBody;
  final envelope = payload is Map<String, dynamic> ? payload : null;
  final dataNode = envelope != null && envelope.containsKey('data')
      ? envelope['data']
      : payload;
  final ok =
      okOverride ??
      (envelope != null && envelope['ok'] is bool
          ? envelope['ok'] as bool
          : statusCode >= 200 && statusCode < 300);
  final message = envelope != null
      ? coalesceText([envelope['message'], envelope['error']], fallback: '')
      : parsedBody is String
      ? parsedBody
      : '';
  final code = envelope != null
      ? coalesceText([envelope['code']], fallback: '')
      : '';
  final data = decoder != null
      ? decoder(dataNode)
      : (dataNode is T ? dataNode : null);

  return ApiResult<T>(
    ok: ok,
    statusCode: statusCode,
    message: message,
    code: code,
    data: data,
    rawData: dataNode,
  );
}

dynamic parseApiBody(dynamic rawBody) {
  if (rawBody == null) return null;
  if (rawBody is Map || rawBody is List) return rawBody;
  if (rawBody is! String) return rawBody;
  final trimmed = rawBody.trim();
  if (trimmed.isEmpty) return null;
  try {
    return jsonDecode(trimmed);
  } catch (_) {
    return trimmed;
  }
}
