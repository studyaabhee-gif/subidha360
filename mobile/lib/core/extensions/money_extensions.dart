import '../../core/l10n/tr.dart';

/// Money is integer paisa everywhere, matching the backend ledger.
extension PaisaFormat on int {
  /// 150050 becomes "Rs 1,500.50".
  String get asRupees {
    final sign = this < 0 ? '-' : '';
    final absolute = abs();
    final rupees = (absolute ~/ 100).toString();
    final paisa = (absolute % 100).toString().padLeft(2, '0');
    final grouped = rupees.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return tr('{0}Rs {1}.{2}', [sign, grouped, paisa]);
  }

  /// Whole rupees for guide prices: 150000 becomes "Rs 1,500".
  String get asRupeesShort => asRupees.replaceFirst(RegExp(r'\.\d\d$'), '');
}

extension RupeeParsing on String {
  /// Reads "1500" or "1500.50" as paisa without going through a double, which
  /// could lose a paisa. Returns null for anything else.
  int? get toPaisa {
    final match = RegExp(r'^(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(trim());
    if (match == null) return null;
    final rupees = int.parse(match[1]!);
    final paisa = int.parse((match[2] ?? '').padRight(2, '0'));
    return rupees * 100 + paisa;
  }
}
