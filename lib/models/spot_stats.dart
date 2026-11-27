import 'place_facts.dart';
import 'review.dart';

/// Ringkasan kondisi sebuah spot yang dihitung dari semua review-nya.
///
/// Review baru diberi bobot lebih besar daripada review lama, karena kondisi
/// WiFi dan keramaian bisa berubah seiring waktu:
///   - umur <= 30 hari  -> bobot 1.0
///   - umur <= 90 hari  -> bobot 0.5
///   - lebih tua        -> bobot 0.25
class SpotStats {
  const SpotStats({
    required this.wifi,
    required this.power,
    required this.quiet,
    required this.comfort,
    required this.reviewCount,
    this.latestCrowd,
    this.latestCrowdAt,
    this.wifiSpeedMbps,
    this.wifiMeasuredAt,
    this.facts = PlaceFacts.empty,
  });

  static const empty = SpotStats(
    wifi: 0,
    power: 0,
    quiet: 0,
    comfort: 0,
    reviewCount: 0,
  );

  /// Rata-rata berbobot tiap aspek (0–5).
  final double wifi;
  final double power;
  final double quiet;
  final double comfort;
  final int reviewCount;

  final CrowdLevel? latestCrowd;
  final DateTime? latestCrowdAt;

  /// Hasil speed test terbaru.
  final double? wifiSpeedMbps;
  final DateTime? wifiMeasuredAt;

  /// Atribut lokal (rokok, AC, parkir, duduk lama, jam ramai).
  final PlaceFacts facts;

  bool get hasData => reviewCount > 0;

  /// Work Score 0–100.
  /// Bobot: WiFi 35%, colokan 25%, ketenangan 20%, kenyamanan 20%.
  int get workScore {
    if (!hasData) return 0;
    final weighted =
        wifi * 0.35 + power * 0.25 + quiet * 0.20 + comfort * 0.20;
    return (weighted / 5 * 100).round();
  }

  static double recencyWeight(Duration age) {
    if (age.inDays <= 30) return 1.0;
    if (age.inDays <= 90) return 0.5;
    return 0.25;
  }

  factory SpotStats.fromReviews(List<Review> reviews, DateTime now) {
    if (reviews.isEmpty) return empty;

    double totalWeight = 0, wifi = 0, power = 0, quiet = 0, comfort = 0;
    for (final r in reviews) {
      final w = recencyWeight(now.difference(r.createdAt));
      totalWeight += w;
      wifi += r.wifi * w;
      power += r.power * w;
      quiet += r.quiet * w;
      comfort += r.comfort * w;
    }

    final newestFirst = [...reviews]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = newestFirst.first;
    final speedReviews = newestFirst.where((r) => r.wifiSpeedMbps != null);
    final latestSpeed = speedReviews.isEmpty ? null : speedReviews.first;

    return SpotStats(
      wifi: wifi / totalWeight,
      power: power / totalWeight,
      quiet: quiet / totalWeight,
      comfort: comfort / totalWeight,
      reviewCount: reviews.length,
      latestCrowd: latest.crowd,
      latestCrowdAt: latest.createdAt,
      wifiSpeedMbps: latestSpeed?.wifiSpeedMbps,
      wifiMeasuredAt: latestSpeed?.createdAt,
      facts: PlaceFacts.fromAnswers([
        for (final r in reviews)
          FactAnswer(
            weight: recencyWeight(now.difference(r.createdAt)),
            createdAt: r.createdAt,
            smoking: r.smoking,
            seating: r.seating,
            motorParking: r.motorParking,
            stay: r.stay,
            busyTimes: r.busyTimes,
          ),
      ]),
    );
  }
}
