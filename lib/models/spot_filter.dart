import 'spot.dart';
import 'spot_stats.dart';

enum SortBy { distance, workScore }

/// Batas nilai untuk tiap filter. Ubah di sini kalau mau aturannya berbeda.
class FilterThresholds {
  /// "WiFi cepat" = hasil speed test terbaru minimal sekian Mbps.
  static const fastWifiMbps = 25.0;

  /// "Banyak colokan" & "Tenang" = rata-rata rating minimal sekian (dari 5).
  static const goodRating = 4.0;
}

/// Kumpulan filter yang sedang aktif di layar Daftar & Peta.
class SpotFilter {
  const SpotFilter({
    this.fastWifi = false,
    this.manyOutlets = false,
    this.quiet = false,
    this.openLate = false,
    this.openNow = false,
    this.sortBy = SortBy.distance,
  });

  final bool fastWifi;
  final bool manyOutlets;
  final bool quiet;
  final bool openLate;
  final bool openNow;
  final SortBy sortBy;

  bool get isActive => fastWifi || manyOutlets || quiet || openLate || openNow;

  bool matches(Spot spot, SpotStats stats, DateTime now) {
    if (fastWifi &&
        (stats.wifiSpeedMbps ?? 0) < FilterThresholds.fastWifiMbps) {
      return false;
    }
    if (manyOutlets && stats.power < FilterThresholds.goodRating) return false;
    if (quiet && stats.quiet < FilterThresholds.goodRating) return false;
    if (openLate && !spot.opensLate) return false;
    if (openNow && !spot.isOpenAt(now)) return false;
    return true;
  }

  SpotFilter copyWith({
    bool? fastWifi,
    bool? manyOutlets,
    bool? quiet,
    bool? openLate,
    bool? openNow,
    SortBy? sortBy,
  }) =>
      SpotFilter(
        fastWifi: fastWifi ?? this.fastWifi,
        manyOutlets: manyOutlets ?? this.manyOutlets,
        quiet: quiet ?? this.quiet,
        openLate: openLate ?? this.openLate,
        openNow: openNow ?? this.openNow,
        sortBy: sortBy ?? this.sortBy,
      );

  /// Reset semua filter, tapi pertahankan urutan.
  SpotFilter cleared() => SpotFilter(sortBy: sortBy);
}
