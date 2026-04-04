typedef JsonMap = Map<String, dynamic>;

JsonMap asJsonMap(dynamic value) {
  if (value is JsonMap) return value;
  if (value is Map) {
    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<JsonMap> asJsonMapList(dynamic value) {
  if (value is! List) return const <JsonMap>[];
  return value.map(asJsonMap).toList(growable: false);
}

String? asString(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return value.toString().trim().isEmpty ? null : value.toString().trim();
}

int? asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool? asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty) return null;
  if (['1', 'true', 'yes', 'on', 'evet'].contains(normalized)) return true;
  if (['0', 'false', 'no', 'off', 'hayir', 'hayır'].contains(normalized)) {
    return false;
  }
  return null;
}

DateTime? asDateTime(dynamic value) {
  final text = asString(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}

String coalesceText(Iterable<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = asString(value);
    if (text != null) return text;
  }
  return fallback;
}

JsonMap normalizeJsonAliases(
  Map<String, dynamic> input,
  Map<String, List<String>> aliases,
) {
  final normalized = asJsonMap(input);
  for (final entry in aliases.entries) {
    if (normalized.containsKey(entry.key) && normalized[entry.key] != null) {
      continue;
    }
    for (final alias in entry.value) {
      if (!normalized.containsKey(alias)) continue;
      final candidate = normalized[alias];
      if (candidate == null) continue;
      normalized[entry.key] = candidate;
      break;
    }
  }
  return normalized;
}

String readRequiredText(dynamic value) => asString(value) ?? '';

String? readOptionalText(dynamic value) => asString(value);

int readRequiredInt(dynamic value) => asInt(value) ?? 0;

int? readOptionalInt(dynamic value) => asInt(value);

bool readRequiredBool(dynamic value) => asBool(value) ?? false;

bool? readOptionalBool(dynamic value) => asBool(value);
