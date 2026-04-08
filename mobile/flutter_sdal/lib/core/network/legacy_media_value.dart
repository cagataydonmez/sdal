String normalizeLegacyMediaValue(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';

  // Legacy SDAL endpoints sometimes serialize missing media fields as the
  // literal strings "yok" or "null" instead of omitting the value.
  if (value.toLowerCase() == 'yok' || value.toLowerCase() == 'null') {
    return '';
  }

  return value;
}
