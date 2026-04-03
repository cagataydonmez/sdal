class ApiResult<T> {
  const ApiResult({
    required this.ok,
    required this.statusCode,
    required this.message,
    required this.code,
    required this.data,
    required this.rawData,
  });

  final bool ok;
  final int statusCode;
  final String message;
  final String code;
  final T? data;
  final dynamic rawData;

  T requireData([String? fallbackMessage]) {
    final value = data;
    if (value != null) return value;
    final resolvedMessage =
        fallbackMessage ??
        (message.isNotEmpty ? message : 'Response did not contain data.');
    throw StateError(resolvedMessage);
  }
}
