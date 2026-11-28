import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../data/spot_repository.dart';
import '../models/place_facts.dart';
import '../models/review.dart';
import '../models/spot.dart';
import '../models/spot_filter.dart';
import '../models/spot_stats.dart';
import '../services/location_service.dart';

/// Hasil percobaan mengirim review.
enum ReviewResult { savedVerified, savedUnverified, limitReached, failed }

/// State utama app: daftar spot, review, filter, pencarian, dan lokasi user.
///
/// Layar memanggil `context.watch<SpotStore>()` sehingga otomatis
/// di-render ulang setiap kali [notifyListeners] dipanggil.
class SpotStore extends ChangeNotifier {
  SpotStore(
    this._repository, {
    LatLng? defaultCenter,
    this.defaultAreaName = 'Jakarta Selatan (area contoh)',
  })  : defaultCenter = defaultCenter ?? LatLng(-6.2450, 106.8080),
        userLocation = defaultCenter ?? LatLng(-6.2450, 106.8080);

  final SpotRepository _repository;

  // ---- Batasan aplikasi -------------------------------------------------

  /// Titik tengah area data. Dipakai kalau lokasi user tidak tersedia.
  /// Data contoh: Jakarta Selatan. Data Supabase: Bali (diatur di main.dart).
  final LatLng defaultCenter;
  final String defaultAreaName;

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
  LatLng userLocation;

  /// Pesan error terakhir saat mengirim review (untuk ditampilkan ke user).
  String? lastReviewError;
  bool hasRealLocation = false;
  bool isLocating = false;

  // ---- Load data --------------------------------------------------------

  /// Muat data spot & review. [locate] = false kalau izin lokasi belum
  /// boleh diminta (misalnya user belum melewati onboarding).
  Future<void> load({bool locate = true}) async {
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
    if (locate) await refreshLocation();
  }

  /// Muat ulang review saja, misalnya setelah user login/logout
  /// (status "review milikku" ikut berubah).
  Future<void> reloadReviews() async {
    try {
      final reviews = await _repository.fetchReviews();
      _reviewsBySpot.clear();
      _statsCache.clear();
      for (final r in reviews) {
        _reviewsBySpot.putIfAbsent(r.spotId, () => []).add(r);
      }
      notifyListeners();
    } catch (_) {
      // Data lama tetap ditampilkan.
    }
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
    SmokingPolicy? smoking,
    Seating? seating,
    bool? motorParking,
    StayPolicy? stay,
    Set<BusyTime> busyTimes = const {},
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
      smoking: smoking,
      seating: seating,
      motorParking: motorParking,
      stay: stay,
      busyTimes: busyTimes,
    );

    // Repository mengembalikan versi tersimpan. Di Supabase, status
    // check-in & nama penulis ditentukan ulang oleh server.
    final Review saved;
    try {
      saved = await _repository.addReview(
        review,
        checkInLocation: hasRealLocation ? userLocation : null,
      );
    } on ReviewLimitException {
      return ReviewResult.limitReached;
    } catch (e) {
      lastReviewError = e.toString();
      return ReviewResult.failed;
    }
    lastReviewError = null;
    _reviewsBySpot.putIfAbsent(spotId, () => []).add(saved);
    _statsCache.remove(spotId);
    notifyListeners();
    return saved.verifiedCheckIn
        ? ReviewResult.savedVerified
        : ReviewResult.savedUnverified;
  }
}
