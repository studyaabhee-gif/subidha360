import '../../core/l10n/tr.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

extension FriendlyDates on DateTime {
  /// "Just now", "5 min ago", "3 hours ago", "Yesterday", "2 Nov".
  String timeAgo([DateTime? now]) {
    final reference = now ?? DateTime.now();
    final local = toLocal();
    final elapsed = reference.difference(local);
    if (elapsed.inMinutes < 1) return tr('Just now');
    if (elapsed.inMinutes < 60) return tr('{0} min ago', [elapsed.inMinutes]);
    if (elapsed.inHours < 24 && local.day == reference.day) {
      final hours = elapsed.inHours;
      return hours == 1 ? tr('1 hour ago') : tr('{0} hours ago', [hours]);
    }
    if (isYesterdayOf(reference)) return tr('Yesterday');
    return shortDate;
  }

  String get shortDate {
    final local = toLocal();
    return '${local.day} ${tr(_months[local.month - 1])}';
  }

  bool isSameDayAs(DateTime other) {
    final a = toLocal();
    final b = other.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool isYesterdayOf(DateTime reference) => isSameDayAs(
    DateTime(reference.year, reference.month, reference.day - 1, 12),
  );

  /// "2 days", "5 hours", "20 minutes", or null once the moment has passed.
  String? timeLeft([DateTime? now]) {
    final left = difference(now ?? DateTime.now());
    if (left.isNegative) return null;
    if (left.inHours >= 48) return tr('{0} days', [left.inDays]);
    if (left.inHours >= 2) return tr('{0} hours', [left.inHours]);
    if (left.inMinutes >= 2) return tr('{0} minutes', [left.inMinutes]);
    return tr('a moment');
  }
}

/// "Nov 2026", for headings over a month of items.
String monthTitle(DateTime d) => '${tr(_months[d.month - 1])} ${d.year}';
