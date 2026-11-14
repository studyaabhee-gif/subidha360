import 'package:flutter_test/flutter_test.dart';
import 'package:subidha360/core/extensions/date_extensions.dart';

void main() {
  final now = DateTime(2026, 11, 6, 15, 0);

  test('timeAgo reads naturally', () {
    expect(now.subtract(const Duration(seconds: 20)).timeAgo(now), 'Just now');
    expect(now.subtract(const Duration(minutes: 5)).timeAgo(now), '5 min ago');
    expect(now.subtract(const Duration(hours: 1)).timeAgo(now), '1 hour ago');
    expect(now.subtract(const Duration(hours: 3)).timeAgo(now), '3 hours ago');
    expect(DateTime(2026, 11, 5, 23).timeAgo(now), 'Yesterday');
    expect(DateTime(2026, 11, 2, 9).timeAgo(now), '2 Nov');
  });

  test('yesterday works across a month boundary', () {
    expect(
      DateTime(2026, 10, 31, 20).timeAgo(DateTime(2026, 11, 1, 9)),
      'Yesterday',
    );
  });

  test('timeLeft picks a sensible unit', () {
    expect(now.add(const Duration(hours: 72)).timeLeft(now), '3 days');
    expect(now.add(const Duration(hours: 5)).timeLeft(now), '5 hours');
    expect(now.add(const Duration(minutes: 20)).timeLeft(now), '20 minutes');
    expect(now.add(const Duration(seconds: 30)).timeLeft(now), 'a moment');
    expect(now.subtract(const Duration(minutes: 1)).timeLeft(now), isNull);
  });
}
