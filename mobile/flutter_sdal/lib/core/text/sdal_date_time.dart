import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

String formatSdalTimestamp(BuildContext context, String raw, {DateTime? now}) =>
    _formatSdalDate(context, raw, now: now)?.text ?? raw;

String formatSdalDateTime(
  BuildContext context,
  DateTime value, {
  DateTime? now,
}) {
  return _formatSdalDateTime(context, value, now: now).text;
}

String formatSdalFullTimestamp(BuildContext context, String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat(
    'd MMMM yyyy HH:mm',
    _localeName(context),
  ).format(parsed.toLocal());
}

String formatSdalEditedLabel(
  BuildContext context,
  String raw, {
  DateTime? now,
}) => _formatSdalLabeledDate(
  context,
  raw,
  now: now,
  turkishVerb: 'düzenlendi',
  englishVerb: 'Edited',
);

String formatSdalCreatedLabel(
  BuildContext context,
  String raw, {
  DateTime? now,
}) => _formatSdalLabeledDate(
  context,
  raw,
  now: now,
  turkishVerb: 'oluşturuldu',
  englishVerb: 'Created',
);

String _formatSdalLabeledDate(
  BuildContext context,
  String raw, {
  required String turkishVerb,
  required String englishVerb,
  DateTime? now,
}) {
  final isTurkish =
      Localizations.localeOf(context).languageCode.toLowerCase() == 'tr';
  final result = _formatSdalDate(context, raw, now: now);
  if (result == null) {
    return isTurkish ? turkishVerb : englishVerb;
  }
  if (isTurkish) {
    return result.isAbsolute
        ? '${result.text} tarihinde $turkishVerb'
        : '${result.text} $turkishVerb';
  }
  return result.isAbsolute
      ? '$englishVerb on ${result.text}'
      : '$englishVerb ${result.text}';
}

class _SdalFormattedDate {
  const _SdalFormattedDate(this.text, {required this.isAbsolute});
  final String text;
  final bool isAbsolute;
}

_SdalFormattedDate? _formatSdalDate(
  BuildContext context,
  String raw, {
  DateTime? now,
}) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return _formatSdalDateTime(context, parsed, now: now);
}

_SdalFormattedDate _formatSdalDateTime(
  BuildContext context,
  DateTime value, {
  DateTime? now,
}) {
  final locale = Localizations.localeOf(context);
  final localeName = _localeName(context);
  final localTime = value.toLocal();
  final currentTime = (now ?? DateTime.now()).toLocal();
  final isTurkish = locale.languageCode.toLowerCase() == 'tr';

  if (localTime.isAfter(currentTime)) {
    final difference = localTime.difference(currentTime);
    final dayDifference = _calendarDayDifference(localTime, currentTime);
    if (difference.inSeconds < 30) {
      return _SdalFormattedDate(isTurkish ? 'şimdi' : 'now', isAbsolute: false);
    }
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes.clamp(1, 59);
      return _SdalFormattedDate(
        isTurkish
            ? '$minutes dakika sonra'
            : 'in $minutes minute${minutes == 1 ? '' : 's'}',
        isAbsolute: false,
      );
    }
    if (dayDifference == 0 && difference.inHours < 24) {
      final hours = difference.inHours.clamp(1, 23);
      return _SdalFormattedDate(
        isTurkish
            ? '$hours saat sonra'
            : 'in $hours hour${hours == 1 ? '' : 's'}',
        isAbsolute: false,
      );
    }
    return _SdalFormattedDate(
      _formatAbsoluteDate(localTime, currentTime, localeName),
      isAbsolute: true,
    );
  }

  final difference = currentTime.difference(localTime);
  final dayDifference = _calendarDayDifference(currentTime, localTime);

  if (difference.inSeconds < 30) {
    return _SdalFormattedDate(isTurkish ? 'şimdi' : 'now', isAbsolute: false);
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes.clamp(1, 59);
    return _SdalFormattedDate(
      isTurkish
          ? '$minutes dakika önce'
          : '$minutes minute${minutes == 1 ? '' : 's'} ago',
      isAbsolute: false,
    );
  }
  if (dayDifference == 0) {
    final hours = difference.inHours.clamp(1, 23);
    return _SdalFormattedDate(
      isTurkish
          ? '$hours saat önce'
          : '$hours hour${hours == 1 ? '' : 's'} ago',
      isAbsolute: false,
    );
  }
  if (dayDifference < 7) {
    return _SdalFormattedDate(
      isTurkish
          ? '$dayDifference gün önce'
          : '$dayDifference day${dayDifference == 1 ? '' : 's'} ago',
      isAbsolute: false,
    );
  }
  if (dayDifference < 14) {
    return _SdalFormattedDate(
      isTurkish ? '1 hafta önce' : '1 week ago',
      isAbsolute: false,
    );
  }

  return _SdalFormattedDate(
    _formatAbsoluteDate(localTime, currentTime, localeName),
    isAbsolute: true,
  );
}

String _formatAbsoluteDate(DateTime value, DateTime now, String localeName) {
  if (_isSameDay(value, now)) {
    return DateFormat('HH:mm', localeName).format(value);
  }
  if (value.year == now.year) {
    return DateFormat('d MMMM HH:mm', localeName).format(value);
  }
  return DateFormat('d MMMM yyyy HH:mm', localeName).format(value);
}

int _calendarDayDifference(DateTime now, DateTime value) {
  final nowDate = DateTime(now.year, now.month, now.day);
  final valueDate = DateTime(value.year, value.month, value.day);
  return nowDate.difference(valueDate).inDays;
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _localeName(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return locale.countryCode?.isNotEmpty == true
      ? '${locale.languageCode}_${locale.countryCode}'
      : locale.languageCode;
}
