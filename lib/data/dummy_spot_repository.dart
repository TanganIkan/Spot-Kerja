import 'package:latlong2/latlong.dart';

import '../models/review.dart';
import '../models/spot.dart';
import 'dummy_data.dart';
import 'local_storage.dart';
import 'spot_repository.dart';

/// Repository versi MVP: data spot & review contoh ada di dalam app,
/// review dari user disimpan di perangkat.
class DummySpotRepository implements SpotRepository {
  DummySpotRepository(this._storage);

  final LocalStorage _storage;

  @override
  Future<List<Spot>> fetchSpots() async {
    // Simulasi jeda jaringan supaya loading state ikut teruji.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return dummySpots;
  }

  @override
  Future<List<Review>> fetchReviews() async => [
        ...buildDummyReviews(DateTime.now()),
        ..._storage.loadUserReviews(),
      ];

  @override
  Future<Review> addReview(Review review, {LatLng? checkInLocation}) async {
    final saved = _storage.loadUserReviews()..add(review);
    await _storage.saveUserReviews(saved);
    return review;
  }
}
