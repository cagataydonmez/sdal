import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

String formatSdalTimestamp(BuildContext context, String raw, {DateTime? now}) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  final locale = Localizations.localeOf(context);
  final localeName = locale.countryCode?.isNotEmpty == true
      ? '${locale.languageCode}_${locale.countryCode}'
      : locale.languageCode;
  final localTime = parsed.toLocal();
  final currentTime = (now ?? DateTime.now()).toLocal();

  if (localTime.isAfter(currentTime)) {
    return _formatAbsoluteDate(localTime, currentTime, localeName);
  }

  final difference = currentTime.difference(localTime);
  final dayDifference = _calendarDayDifference(currentTime, localTime);
  final isTurkish = locale.languageCode.toLowerCase() == 'tr';

  if (difference.inSeconds < 30) {
    return isTurkish ? 'Şimdi' : 'Now';
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes.clamp(1, 59);
    return isTurkish
        ? '$minutes Dakika Önce'
        : '$minutes minute${minutes == 1 ? '' : 's'} ago';
  }
  if (dayDifference == 0) {
    return DateFormat('HH:mm', localeName).format(localTime);
  }
  if (dayDifference < 7) {
    return isTurkish
        ? '$dayDifference gün önce'
        : '$dayDifference day${dayDifference == 1 ? '' : 's'} ago';
  }
  if (dayDifference < 14) {
    return isTurkish ? '1 Hafta önce' : '1 week ago';
  }

  return _formatAbsoluteDate(localTime, currentTime, localeName);
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
