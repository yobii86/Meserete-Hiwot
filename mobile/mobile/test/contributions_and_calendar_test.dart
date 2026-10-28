import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/utils/formatters.dart';

void main() {
  group('Ethiopian Calendar Calculations and Boundaries', () {
    test('Ethiopian month day counts and leap year Pagume', () {
      // Regular months 1-12 always have 30 days
      for (var m = 1; m <= 12; m++) {
        expect(EthiopianDate.daysInMonth(2016, m), 30);
        expect(EthiopianDate.daysInMonth(2017, m), 30);
        expect(EthiopianDate.daysInMonth(2018, m), 30);
        expect(EthiopianDate.daysInMonth(2019, m), 30);
      }

      // Pagume (Month 13): 6 days if year % 4 == 3 (e.g. 2011, 2015, 2019), otherwise 5 days
      expect(EthiopianDate.daysInMonth(2016, 13), 5); // 2016 % 4 == 0
      expect(EthiopianDate.daysInMonth(2017, 13), 5); // 2017 % 4 == 1
      expect(EthiopianDate.daysInMonth(2018, 13), 5); // 2018 % 4 == 2
      expect(EthiopianDate.daysInMonth(2019, 13), 6); // 2019 % 4 == 3 (leap year)
    });

    test('Consecutive month period calculations for contributions', () {
      // Period format YYYY-MM
      // If member selects 2017-01 and 3 months, coverage end must be 2017-03
      final start = '2017-01';
      final parts = start.split('-');
      var y = int.parse(parts[0]);
      var m = int.parse(parts[1]);
      final months = 3;

      for (var i = 1; i < months; i++) {
        m++;
        if (m > 12) {
          m = 1;
          y++;
        }
      }

      final end = '$y-${m.toString().padLeft(2, '0')}';
      expect(end, '2017-03');

      // Year wrap-around: 2017-11 + 3 months -> 2017-11, 2017-12, 2018-01
      var yWrap = 2017;
      var mWrap = 11;
      for (var i = 1; i < 3; i++) {
        mWrap++;
        if (mWrap > 12) {
          mWrap = 1;
          yWrap++;
        }
      }
      expect('$yWrap-${mWrap.toString().padLeft(2, '0')}', '2018-01');
    });

    test('Expected amount calculation without client trust', () {
      const workerRate = 200.0;
      const studentRate = 100.0;

      expect(workerRate * 1, 200.0);
      expect(workerRate * 3, 600.0);
      expect(workerRate * 12, 2400.0);

      expect(studentRate * 1, 100.0);
      expect(studentRate * 6, 600.0);
    });
  });
}
