import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/core/text/sdal_date_time.dart';

void main() {
  Future<T> withTurkishContext<T>(
    WidgetTester tester,
    T Function(BuildContext context) callback,
  ) async {
    late T result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) {
            result = callback(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('formats recent Turkish timestamps with relative labels', (
    tester,
  ) async {
    final now = DateTime.parse('2026-05-07T12:18:53.123Z');

    final current = await withTurkishContext(
      tester,
      (context) =>
          formatSdalTimestamp(context, '2026-05-07T12:18:31.123Z', now: now),
    );
    final minutes = await withTurkishContext(
      tester,
      (context) =>
          formatSdalTimestamp(context, '2026-05-07T12:17:53.123Z', now: now),
    );
    final days = await withTurkishContext(
      tester,
      (context) =>
          formatSdalTimestamp(context, '2026-05-06T12:18:53.123Z', now: now),
    );

    expect(current, 'şimdi');
    expect(minutes, '1 dakika önce');
    expect(days, '1 gün önce');
  });

  testWidgets('formats older timestamps as readable local Turkish dates', (
    tester,
  ) async {
    final now = DateTime(2026, 5, 21, 15, 18, 53);

    final value = await withTurkishContext(
      tester,
      (context) =>
          formatSdalTimestamp(context, '2026-05-07T15:18:53.123', now: now),
    );

    expect(value, '7 Mayıs 15:18');
  });
}
