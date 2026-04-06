String plainTextFromRichContent(String raw) {
  if (raw.trim().isEmpty) return '';

  var text = raw.replaceAll('\r\n', '\n');
  text = _decodeHtmlEntities(text);
  text = _replaceSmileyImages(text);
  text = text
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(
          r'<\s*/\s*(p|div|section|article|blockquote)\s*>',
          caseSensitive: false,
        ),
        '\n',
      )
      .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<\s*/\s*li\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(
          r'<\s*(p|div|section|article|blockquote|ul|ol)[^>]*>',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '');
  text = _decodeHtmlEntities(text).replaceAll('\u00A0', ' ');
  text = _replaceSmileys(text);
  return text
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n[ \t]+'), '\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _decodeHtmlEntities(String raw) {
  var text = raw;
  for (var index = 0; index < 3; index++) {
    final decoded = text.replaceAllMapped(
      RegExp(r'&(#x?[0-9A-Fa-f]+|[A-Za-z]+);'),
      (match) {
        final token = match.group(1)!;
        if (token.startsWith('#x') || token.startsWith('#X')) {
          final value = int.tryParse(token.substring(2), radix: 16);
          return value == null ? match.group(0)! : String.fromCharCode(value);
        }
        if (token.startsWith('#')) {
          final value = int.tryParse(token.substring(1));
          return value == null ? match.group(0)! : String.fromCharCode(value);
        }
        return _namedHtmlEntities[token.toLowerCase()] ?? match.group(0)!;
      },
    );
    if (decoded == text) break;
    text = decoded;
  }
  return text;
}

String _replaceSmileys(String raw) {
  var text = raw;
  for (final replacement in _smileyReplacements) {
    text = text.replaceAll(replacement.$1, replacement.$2);
  }
  return text;
}

String _replaceSmileyImages(String raw) {
  return raw.replaceAllMapped(
    RegExp(
      r'''<img[^>]+src\s*=\s*["']?/smiley/(\d+)\.gif["']?[^>]*>''',
      caseSensitive: false,
    ),
    (match) {
      final index = int.tryParse(match.group(1) ?? '');
      if (index == null) return '';
      return _smileyImageMap[index] ?? '';
    },
  );
}

const Map<String, String> _namedHtmlEntities = {
  'amp': '&',
  'apos': "'",
  'quot': '"',
  'nbsp': ' ',
  'lt': '<',
  'gt': '>',
  'hellip': '...',
  'ndash': '-',
  'mdash': '--',
  'bull': '•',
  'middot': '·',
  'rsquo': "'",
  'lsquo': "'",
  'rdquo': '"',
  'ldquo': '"',
};

const List<(String, String)> _smileyReplacements = [
  (":'-(", '😢'),
  (":'(", '😢'),
  ('<3', '❤️'),
  (':-D', '😄'),
  (':D', '😄'),
  (';-)', '😉'),
  (';)', '😉'),
  (':-)', '🙂'),
  (':)', '🙂'),
  (':-(', '🙁'),
  (':(', '🙁'),
  (':-P', '😋'),
  (':P', '😋'),
  (':-p', '😋'),
  (':p', '😋'),
  ('B-)', '😎'),
  ('B)', '😎'),
  (':-O', '😮'),
  (':O', '😮'),
  (':-o', '😮'),
  (':o', '😮'),
];

const Map<int, String> _smileyImageMap = {
  1: '🙂',
  2: '😡',
  3: '😄',
  4: '😎',
  5: '😢',
  6: '🫣',
  7: '😄',
  8: '😘',
  9: '🤩',
  10: '🤐',
  11: '😉',
  12: '🙁',
  13: '😮',
  14: '😋',
  15: '🤨',
  16: '😉',
};
