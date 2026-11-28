import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../models/review.dart';
import '../models/spot.dart';

/// Kontrak sumber data spot.
///
/// UI dan state hanya bergantung pada kontrak ini, bukan pada implementasinya:
///   - [DummySpotRepository]: data contoh di dalam app (tanpa internet)
///   - [SupabaseSpotRepository]: data sungguhan dari Supabase
abstract class SpotRepository {
  /// true kalau repository bisa menyimpan foto dari user.
  bool get supportsPhotos;

  Future<List<Spot>> fetchSpots();
  Future<List<Review>> fetchReviews();

  /// Simpan review lalu kembalikan versi yang tersimpan.
  ///
  /// [checkInLocation] = posisi user saat ini (kalau ada), dipakai untuk
  /// menentukan check-in terverifikasi. [photos] = foto JPEG yang sudah
  /// diproses [PhotoProcessor]; review yang dikembalikan berisi URL foto
  /// yang BERHASIL diunggah (bisa lebih sedikit dari yang dikirim).
  /// Melempar [ReviewLimitException] kalau user sudah mereview spot ini
  /// hari ini.
  Future<Review> addReview(
    Review review, {
    LatLng? checkInLocation,
    List<Uint8List> photos = const [],
  });
}

/// User sudah mencapai batas 1 review per spot per hari.
class ReviewLimitException implements Exception {
  const ReviewLimitException();

  @override
  String toString() => 'Batas 1 review per tempat per hari tercapai.';
}
