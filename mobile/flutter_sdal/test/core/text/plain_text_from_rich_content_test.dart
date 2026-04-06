import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/text/plain_text_from_rich_content.dart';

void main() {
  test('decodes html entities, strips tags, and preserves line breaks', () {
    expect(
      plainTextFromRichContent(
        '&lt;p&gt;Merhaba&nbsp;<strong>dunya</strong>&lt;/p&gt;',
      ),
      'Merhaba dunya',
    );
    expect(
      plainTextFromRichContent('<div>Ilk satir<br>ikinci satir</div>'),
      'Ilk satir\nikinci satir',
    );
  });

  test('renders legacy emoticons as modern emoji', () {
    expect(
      plainTextFromRichContent('Selam :) Nasilsin &lt;3'),
      'Selam 🙂 Nasilsin ❤️',
    );
    expect(
      plainTextFromRichContent('Bu cok iyi :D ama bazen :('),
      'Bu cok iyi 😄 ama bazen 🙁',
    );
  });
}
