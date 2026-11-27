import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:spot_kerja/models/review.dart';
import 'package:spot_kerja/models/spot.dart';
import 'package:spot_kerja/models/spot_filter.dart';
import 'package:spot_kerja/models/spot_stats.dart';

void main() {
  final now = DateTime(2026, 11, 27, 14);

  Review review({
    required int score,
    Duration age = Duration.zero,
    double? speed,
    CrowdLevel crowd = CrowdLevel.sedang,
  }) =>
      Review(
        id: 'r$score${age.inDays}',
        spotId: 's1',
        author: 'Tes',
        wifi: score,
        power: score,
        quiet: score,
        comfort: score,
        crowd: crowd,
        wifiSpeedMbps: speed,
        createdAt: now.subtract(age),
      );

  final spot = Spot(
    id: 's1',
    name: 'Tes',
    area: 'Tes',
    address: 'Tes',
    location: LatLng(0, 0),
    openHour: 8,
    closeHour: 22,
    priceLevel: 2,
    category: SpotCategory.kafe,
  );

  group('Work Score', () {
    test('tanpa review = 0 dan hasData false', () {
      final stats = SpotStats.fromReviews([], now);
      expect(stats.workScore, 0);
      expect(stats.hasData, isFalse);
    });

    test('semua aspek bernilai 5 = 100', () {
      expect(SpotStats.fromReviews([review(score: 5)], now).workScore, 100);
    });

    test('review baru lebih berpengaruh daripada review lama', () {
      final stats = SpotStats.fromReviews([
        review(score: 5),
        review(score: 1, age: const Duration(days: 120)),
      ], now);
      // (5 * 1.0 + 1 * 0.25) / 1.25 = 4.2
      expect(stats.wifi, closeTo(4.2, 0.001));
    });

    test('speed test & keramaian diambil dari review terbaru', () {
      final stats = SpotStats.fromReviews([
        review(score: 4, age: const Duration(days: 5), speed: 10, crowd: CrowdLevel.ramai),
        review(score: 4, age: const Duration(hours: 1), crowd: CrowdLevel.sepi),
        review(score: 4, age: const Duration(days: 1), speed: 50),
      ], now);
      expect(stats.wifiSpeedMbps, 50);
      expect(stats.latestCrowd, CrowdLevel.sepi);
    });
  });

  group('Filter', () {
    test('WiFi cepat butuh speed test >= batas', () {
      const filter = SpotFilter(fastWifi: true);
      final slow = SpotStats.fromReviews([review(score: 5, speed: 10)], now);
      final fast = SpotStats.fromReviews([review(score: 5, speed: 30)], now);
      expect(filter.matches(spot, slow, now), isFalse);
      expect(filter.matches(spot, fast, now), isTrue);
    });

    test('Buka sekarang mengikuti jam buka', () {
      const filter = SpotFilter(openNow: true);
      final stats = SpotStats.fromReviews([review(score: 4)], now);
      expect(filter.matches(spot, stats, DateTime(2026, 11, 27, 9)), isTrue);
      expect(filter.matches(spot, stats, DateTime(2026, 11, 27, 23)), isFalse);
    });

    test('cleared() mereset filter tapi mempertahankan urutan', () {
      const filter = SpotFilter(quiet: true, sortBy: SortBy.workScore);
      final cleared = filter.cleared();
      expect(cleared.isActive, isFalse);
      expect(cleared.sortBy, SortBy.workScore);
    });
  });
}
