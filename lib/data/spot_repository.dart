import 'package:latlong2/latlong.dart';

import '../models/review.dart';
import '../models/spot.dart';

/// Kontrak sumber data spot.
///
/// UI dan state hanya bergantung pada kontrak ini, bukan pada implementasinya:
///   - [DummySpotRepository]: data contoh di dalam app (tanpa internet)
///   - [SupabaseSpotRepository]: data sungguhan dari Supabase
abstract class SpotRepository {
  Future<List<Spot>> fetchSpots();
  Future<List<Review>> fetchReviews();

  /// Simpan review lalu kembalikan versi yang tersimpan.
  ///
  /// [checkInLocation] = posisi user saat ini (kalau ada), dipakai untuk
  /// menentukan check-in terverifikasi. Melempar [ReviewLimitException]
  /// kalau user sudah mereview spot ini hari ini.
  Future<Review> addReview(Review review, {LatLng? checkInLocation});
}

/// User sudah mencapai batas 1 review per spot per hari.
class ReviewLimitException implements Exception {
  const ReviewLimitException();

  @override
  String toString() => 'Batas 1 review per tempat per hari tercapai.';
}
