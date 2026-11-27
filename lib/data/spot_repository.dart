import '../models/review.dart';
import '../models/spot.dart';

/// Kontrak sumber data spot.
///
/// UI dan state hanya bergantung pada kontrak ini, bukan pada implementasinya.
/// Sekarang yang dipakai [DummySpotRepository]; nanti tinggal dibuat
/// `SupabaseSpotRepository` tanpa perlu mengubah layar-layarnya.
abstract class SpotRepository {
  Future<List<Spot>> fetchSpots();
  Future<List<Review>> fetchReviews();
  Future<void> addReview(Review review);
}
