import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/network/api_result_parser.dart';
import 'package:flutter_sdal/core/network/json_utils.dart';

void main() {
  test('parseApiResult supports envelope payloads', () {
    final result = parseApiResult<JsonMap>(
      200,
      '{"ok":true,"code":"OK","message":"hazir","data":{"id":7,"isim":"Ada"}}',
      decoder: asJsonMap,
    );

    expect(result.ok, isTrue);
    expect(result.code, 'OK');
    expect(result.message, 'hazir');
    expect(result.requireData()['id'], 7);
    expect(result.requireData()['isim'], 'Ada');
  });

  test('parseApiResult supports plain json bodies', () {
    final result = parseApiResult<JsonMap>(
      200,
      '{"id":4,"state":"active"}',
      decoder: asJsonMap,
    );

    expect(result.ok, isTrue);
    expect(result.message, isEmpty);
    expect(result.requireData()['id'], 4);
    expect(result.rawData['state'], 'active');
  });

  test('parseApiResult preserves plain text error bodies', () {
    final result = parseApiResult<void>(
      500,
      'Bakim modunda',
      okOverride: false,
    );

    expect(result.ok, isFalse);
    expect(result.statusCode, 500);
    expect(result.message, 'Bakim modunda');
    expect(result.rawData, 'Bakim modunda');
  });
}
