import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final _monthYear = DateFormat('MMM yyyy');
  static final _dayMonthYear = DateFormat('d MMM yyyy');
  static final _apiFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
  static final _shortDate = DateFormat('d MMM');

  static String monthYear(DateTime d) => _monthYear.format(d);
  static String dayMonthYear(DateTime d) => _dayMonthYear.format(d);
  static String shortDate(DateTime d) => _shortDate.format(d);
  static String toApi(DateTime d) => _apiFormat.format(d.toUtc());

  static DateTime fromApi(String s) =>
      DateTime.parse(s).toLocal();

  static String groupLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return _dayMonthYear.format(d);
  }
}
