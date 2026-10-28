import 'package:account/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('分相加不会出现浮点误差', () {
    expect(centsFromYuan(0.1) + centsFromYuan(0.2), 30);
    expect(formatYuan(30), '0.30');
    expect(formatYuan(146000), '1460.00');
    expect(formatYuan(-46000), '-460.00');
    expect(formatYuan(0), '0.00');
  });
}
