import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:spot_kerja/models/place_facts.dart';
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
    avgPrice: 45000,
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

  group('Atribut lokal', () {
    Review fact({
      Duration age = Duration.zero,
      SmokingPolicy? smoking,
      Seating? seating,
      bool? parking,
      StayPolicy? stay,
      Set<BusyTime> busy = const {},
    }) =>
        Review(
          id: 'f${age.inHours}${smoking?.name}${busy.length}',
          spotId: 's1',
          author: 'Tes',
          wifi: 4,
          power: 4,
          quiet: 4,
          comfort: 4,
          crowd: CrowdLevel.sedang,
          createdAt: now.subtract(age),
          smoking: smoking,
          seating: seating,
          motorParking: parking,
          stay: stay,
          busyTimes: busy,
        );

    test('tanpa jawaban = belum ada info', () {
      final facts = SpotStats.fromReviews([fact()], now).facts;
      expect(facts.hasData, isFalse);
      expect(facts.smoking, isNull);
    });

    test('suara terbanyak menang', () {
      final facts = SpotStats.fromReviews([
        fact(smoking: SmokingPolicy.allowed, age: const Duration(days: 1)),
        fact(smoking: SmokingPolicy.smokeFree, age: const Duration(days: 2)),
        fact(smoking: SmokingPolicy.smokeFree, age: const Duration(days: 3)),
      ], now).facts;
      expect(facts.smoking, SmokingPolicy.smokeFree);
      expect(facts.reportCount, 3);
    });

    test('laporan lama kalah dari laporan baru (bobot kebaruan)', () {
      final facts = SpotStats.fromReviews([
        // 2 laporan lama (bobot 0.25 + 0.25) vs 1 laporan baru (bobot 1.0)
        fact(parking: false, age: const Duration(days: 200)),
        fact(parking: false, age: const Duration(days: 150)),
        fact(parking: true, age: const Duration(days: 2)),
      ], now).facts;
      expect(facts.motorParking, isTrue);
    });

    test('seri -> jawaban terbaru yang dipakai', () {
      final facts = SpotStats.fromReviews([
        fact(stay: StayPolicy.minimumOrder, age: const Duration(days: 5)),
        fact(stay: StayPolicy.unlimited, age: const Duration(days: 1)),
      ], now).facts;
      expect(facts.stay, StayPolicy.unlimited);
    });

    test('jam ramai tampil kalau dilaporkan >= separuh', () {
      final facts = SpotStats.fromReviews([
        fact(busy: {BusyTime.sore, BusyTime.malam}),
        fact(busy: {BusyTime.sore}),
        fact(busy: {BusyTime.pagi, BusyTime.sore}),
      ], now).facts;
      expect(facts.busyTimes, {BusyTime.sore});
    });

    test('filter bebas rokok menerima area rokok terpisah', () {
      const filter = SpotFilter(smokeFree: true);
      SpotStats statsWith(SmokingPolicy p) =>
          SpotStats.fromReviews([fact(smoking: p)], now);
      expect(filter.matches(spot, statsWith(SmokingPolicy.smokeFree), now),
          isTrue);
      expect(filter.matches(spot, statsWith(SmokingPolicy.separateArea), now),
          isTrue);
      expect(filter.matches(spot, statsWith(SmokingPolicy.allowed), now),
          isFalse);
    });

    test('filter atribut lokal menolak spot tanpa info', () {
      final noInfo = SpotStats.fromReviews([fact()], now);
      for (final filter in const [
        SpotFilter(smokeFree: true),
        SpotFilter(airConditioned: true),
        SpotFilter(motorParking: true),
        SpotFilter(longStay: true),
      ]) {
        expect(filter.matches(spot, noInfo, now), isFalse);
      }
    });

    test('JSON: simpan & baca ulang atribut lokal', () {
      final original = fact(
        smoking: SmokingPolicy.separateArea,
        seating: Seating.both,
        parking: true,
        stay: StayPolicy.timeLimited,
        busy: {BusyTime.pagi, BusyTime.malam},
      );
      final copy = Review.fromJson(original.toJson());
      expect(copy.smoking, SmokingPolicy.separateArea);
      expect(copy.seating, Seating.both);
      expect(copy.motorParking, isTrue);
      expect(copy.stay, StayPolicy.timeLimited);
      expect(copy.busyTimes, {BusyTime.pagi, BusyTime.malam});
    });

    test('JSON: review versi lama (tanpa atribut lokal) tetap terbaca', () {
      final legacy = fact().toJson()
        ..remove('smoking')
        ..remove('seating')
        ..remove('motorParking')
        ..remove('stay')
        ..remove('busyTimes');
      final copy = Review.fromJson(legacy);
      expect(copy.smoking, isNull);
      expect(copy.busyTimes, isEmpty);
    });
  });
}
