import 'package:flutter_test/flutter_test.dart';
import 'package:spot_kerja/models/review.dart';
import 'package:spot_kerja/models/spot_stats.dart';
import 'package:spot_kerja/utils/format.dart';

void main() {
  group('parseRupiah', () {
    test('berbagai cara menulis 35 ribu', () {
      for (final input in ['35000', '35.000', '35,000', '35rb', '35 rb', '35 ribu', '35k', 'Rp 35.000', '35RB']) {
        expect(parseRupiah(input), 35000, reason: input);
      }
    });
    test('desimal & juta', () {
      expect(parseRupiah('27,5rb'), 27500);
      expect(parseRupiah('1.250.000'), 1250000);
    });
    test('tidak valid -> null', () {
      for (final input in ['', 'mahal', '35.00', 'rb', '3,5,0']) {
        expect(parseRupiah(input), isNull, reason: input);
      }
    });
  });

  test('formatRupiahShort', () {
    expect(formatRupiahShort(25000), '25rb');
    expect(formatRupiahShort(27500), '28rb');
    expect(formatRupiahShort(1250000), '1,3jt');
    expect(formatRupiahShort(2000000), '2jt');
  });

  group('median pengeluaran', () {
    Review r(int? spend) => Review(
          id: 'r$spend',
          spotId: 's1',
          author: 'Tes',
          wifi: 4,
          power: 4,
          quiet: 4,
          comfort: 4,
          crowd: CrowdLevel.sedang,
          createdAt: DateTime(2026, 11, 27),
          spendPerPerson: spend,
        );
    final now = DateTime(2026, 11, 28);

    test('median tahan terhadap laporan ekstrem', () {
      final stats = SpotStats.fromReviews([r(25000), r(30000), r(28000), r(250000)], now);
      // urut: 25k 28k 30k 250k -> median (28k+30k)/2 = 29k (rata-rata akan 83k)
      expect(stats.typicalSpend, 29000);
      expect(stats.spendReports, 4);
    });

    test('review tanpa laporan harga diabaikan', () {
      final stats = SpotStats.fromReviews([r(null), r(40000), r(null)], now);
      expect(stats.typicalSpend, 40000);
      expect(stats.spendReports, 1);
    });

    test('tanpa laporan -> null', () {
      expect(SpotStats.fromReviews([r(null)], now).typicalSpend, isNull);
    });
  });
}
