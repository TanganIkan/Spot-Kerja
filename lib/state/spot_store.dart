import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../data/spot_repository.dart';
import '../models/review.dart';
import '../models/spot.dart';
import '../models/spot_filter.dart';
import '../models/spot_stats.dart';
import '../services/location_service.dart';

/// Hasil percobaan mengirim review.
enum ReviewResult { savedVerified, savedUnverified, limitReached }

/// State utama app: daftar spot, review, filter, pencarian, dan lokasi user.
///
/// Layar memanggil `context.watch<SpotStore>()` sehingga otomatis
/// di-render ulang setiap kali [notifyListeners] dipanggil.
class SpotStore extends ChangeNotifier {
  SpotStore(this._repository);

  final SpotRepository _repository;

  // ---- Batasan aplikasi -------------------------------------------------

  /// Titik tengah data contoh. Dipakai kalau lokasi user tidak tersedia.
  static final defaultCenter = LatLng(-6.2450, 106.8080);
  static const defaultAreaName = 'Jakarta Selatan';

  /// Review dianggap "check-in terverifikasi" kalau user berada dalam radius ini.
  static const checkInRadiusMeters = 200.0;

  /// Anti-spam: satu user hanya boleh 1 review per spot per hari.
  static const maxReviewsPerSpotPerDay = 1;

  // ---- State ------------------------------------------------------------

  List<Spot> _spots = [];
  final Map<String, List<Review>> _reviewsBySpot = {};
  final Map<String, SpotStats> _statsCache = {};
  static const _distance = Distance();

  bool isLoading = true;
  String? error;
  SpotFilter filter = const SpotFilter();
  String query = '';
  LatLng userLocation = defaultCenter;
  bool hasRealLocation = false;
  bool isLocating = false;

  // ---- Load data --------------------------------------------------------

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      _spots = await _repository.fetchSpots();
      final reviews = await _repository.fetchReviews();
      _reviewsBySpot.clear();
      _statsCache.clear();
      for (final r in reviews) {
        _reviewsBySpot.putIfAbsent(r.spotId, () => []).add(r);
      }
    } catch (e) {
      error = 'Gagal memuat data spot.';
    }
    isLoading = false;
    notifyListeners();
    await refreshLocation();
  }

  Future<void> refreshLocation() async {
    isLocating = true;
    notifyListeners();
    final pos = await LocationService.currentPosition();
    if (pos != null) {
      userLocation = pos;
      hasRealLocation = true;
    }
    isLocating = false;
    notifyListeners();
  }

  // ---- Query ------------------------------------------------------------

  List<Spot> get allSpots => List.unmodifiable(_spots);

  Spot? spotById(String id) {
    for (final s in _spots) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<Review> reviewsFor(String spotId) =>
      [...?_reviewsBySpot[spotId]]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  SpotStats statsFor(String spotId) => _statsCache.putIfAbsent(
        spotId,
        () => SpotStats.fromReviews(
          _reviewsBySpot[spotId] ?? const [],
          DateTime.now(),
        ),
      );

  double distanceTo(Spot spot) =>
      _distance.as(LengthUnit.Meter, userLocation, spot.location);

  /// Spot yang lolos pencarian + filter, sudah diurutkan.
  List<Spot> get visibleSpots {
    final now = DateTime.now();
    final q = query.trim().toLowerCase();
    final result = _spots.where((s) {
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !s.area.toLowerCase().contains(q)) {
        return false;
      }
      return filter.matches(s, statsFor(s.id), now);
    }).toList();

    switch (filter.sortBy) {
      case SortBy.distance:
        result.sort((a, b) => distanceTo(a).compareTo(distanceTo(b)));
      case SortBy.workScore:
        result.sort(
          (a, b) => statsFor(b.id).workScore.compareTo(statsFor(a.id).workScore),
        );
    }
    return result;
  }

  // ---- Aksi user --------------------------------------------------------

  void setFilter(SpotFilter value) {
    filter = value;
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  bool hasReachedReviewLimit(String spotId) {
    final now = DateTime.now();
    final todayCount = (_reviewsBySpot[spotId] ?? const <Review>[])
        .where((r) =>
            r.isMine &&
            r.createdAt.year == now.year &&
            r.createdAt.month == now.month &&
            r.createdAt.day == now.day)
        .length;
    return todayCount >= maxReviewsPerSpotPerDay;
  }

  Future<ReviewResult> addReview({
    required String spotId,
    required int wifi,
    required int power,
    required int quiet,
    required int comfort,
    required CrowdLevel crowd,
    double? wifiSpeedMbps,
    String comment = '',
  }) async {
    if (hasReachedReviewLimit(spotId)) return ReviewResult.limitReached;
    final spot = spotById(spotId);
    if (spot == null) throw ArgumentError('Spot $spotId tidak ditemukan');

    // Cek ulang lokasi saat submit untuk menentukan status check-in.
    await refreshLocation();
    final verified =
        hasRealLocation && distanceTo(spot) <= checkInRadiusMeters;

    final review = Review(
      id: 'u-${DateTime.now().microsecondsSinceEpoch}',
      spotId: spotId,
      author: 'Kamu',
      wifi: wifi,
      power: power,
      quiet: quiet,
      comfort: comfort,
      crowd: crowd,
      wifiSpeedMbps: wifiSpeedMbps,
      comment: comment.trim(),
      createdAt: DateTime.now(),
      verifiedCheckIn: verified,
      isMine: true,
    );

    await _repository.addReview(review);
    _reviewsBySpot.putIfAbsent(spotId, () => []).add(review);
    _statsCache.remove(spotId);
    notifyListeners();
    return verified ? ReviewResult.savedVerified : ReviewResult.savedUnverified;
  }
}
