import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

String formatSdalTimestamp(BuildContext context, String raw, {DateTime? now}) =>
    _formatSdalDate(context, raw, now: now)?.text ?? raw;

String formatSdalEditedLabel(
  BuildContext context,
  String raw, {
  DateTime? now,
}) {
  final isTurkish =
      Localizations.localeOf(context).languageCode.toLowerCase() == 'tr';
  final result = _formatSdalDate(context, raw, now: now);
  if (result == null) {
    return isTurkish ? 'düzenlendi' : 'Edited';
  }
  if (isTurkish) {
    return result.isAbsolute
        ? '${result.text} tarihinde düzenlendi'
        : '${result.text} düzenlendi';
  }
  return result.isAbsolute
      ? 'Edited on ${result.text}'
      : 'Edited ${result.text}';
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

  final locale = Localizations.localeOf(context);
  final localeName = locale.countryCode?.isNotEmpty == true
      ? '${locale.languageCode}_${locale.countryCode}'
      : locale.languageCode;
  final localTime = parsed.toLocal();
  final currentTime = (now ?? DateTime.now()).toLocal();

  if (localTime.isAfter(currentTime)) {
    return _SdalFormattedDate(
      _formatAbsoluteDate(localTime, currentTime, localeName),
      isAbsolute: true,
    );
  }

  final difference = currentTime.difference(localTime);
  final dayDifference = _calendarDayDifference(currentTime, localTime);
  final isTurkish = locale.languageCode.toLowerCase() == 'tr';

  if (difference.inSeconds < 30) {
    return _SdalFormattedDate(
      isTurkish ? 'Şimdi' : 'Now',
      isAbsolute: false,
    );
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes.clamp(1, 59);
    return _SdalFormattedDate(
      isTurkish
          ? '$minutes Dakika Önce'
          : '$minutes minute${minutes == 1 ? '' : 's'} ago',
      isAbsolute: false,
    );
  }
  if (dayDifference == 0) {
    return _SdalFormattedDate(
      DateFormat('HH:mm', localeName).format(localTime),
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
      isTurkish ? '1 Hafta önce' : '1 week ago',
      isAbsolute: false,
    );
  }

  return _SdalFormattedDate(
    _formatAbsoluteDate(localTime, currentTime, localeName),
    isAbsolute: true,
  );
}

String _formatAbsoluteDate(
  DateTime value,
  DateTime now,
  String localeName,
) {
  if (_isSameDay(value, now)) {
    return DateFormat('HH:mm', localeName).format(value);
  }
  if (value.year == now.year) {
    return DateFormat('d MMMM', localeName).format(value);
  }
  return DateFormat('d MMMM yyyy', localeName).format(value);
}

int _calendarDayDifference(DateTime now, DateTime value) {
  final nowDate = DateTime(now.year, now.month, now.day);
  final valueDate = DateTime(value.year, value.month, value.day);
  return nowDate.difference(valueDate).inDays;
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
