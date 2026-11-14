import 'package:flutter_test/flutter_test.dart';
import 'package:subidha360/core/extensions/money_extensions.dart';

void main() {
  test('formats paisa as rupees', () {
    expect(0.asRupees, 'Rs 0.00');
    expect(5.asRupees, 'Rs 0.05');
    expect(150050.asRupees, 'Rs 1,500.50');
    expect(100000000.asRupees, 'Rs 1,000,000.00');
    expect((-2500).asRupees, '-Rs 25.00');
  });

  test('parses rupees without losing a paisa', () {
    expect('1500'.toPaisa, 150000);
    expect('1500.5'.toPaisa, 150050);
    expect('19.99'.toPaisa, 1999);
    expect('0.07'.toPaisa, 7);
    expect(' 12 '.toPaisa, 1200);
  });

  test('rejects anything that is not an amount', () {
    for (final text in ['', 'abc', '1.234', '-5', '1,500', '1.', '.5']) {
      expect(text.toPaisa, isNull, reason: text);
    }
  });
}
