import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/place_facts.dart';
import '../models/review.dart';
import '../models/spot.dart';
import 'spot_repository.dart';

/// Repository yang membaca & menulis data ke Supabase.
///
/// Struktur tabelnya ada di supabase/migrations/. Aturan penting (check-in
/// terverifikasi, nama penulis, batas 1 review/hari) dijalankan di server,
/// jadi nilai yang dikirim app untuk hal-hal itu diabaikan.
class SupabaseSpotRepository implements SpotRepository {
  SupabaseSpotRepository(this._client);

  final SupabaseClient _client;

  /// Batas jumlah review yang diambil sekaligus (cukup untuk tahap awal).
  static const maxReviews = 2000;

  static const _reviewColumns = 'id, spot_id, user_id, author_name, wifi, '
      'power, quiet, comfort, crowd, wifi_speed_mbps, comment, smoking, '
      'seating, motor_parking, stay, busy_times, verified_check_in, '
      'visited_at';

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<List<Spot>> fetchSpots() async {
    final rows = await _client.from('spots_view').select();
    return [for (final row in rows) _spotFromRow(row)];
  }

  @override
  Future<List<Review>> fetchReviews() async {
    final rows = await _client
        .from('reviews')
        .select(_reviewColumns)
        .order('visited_at', ascending: false)
        .limit(maxReviews);
    final me = _currentUserId;
    return [for (final row in rows) _reviewFromRow(row, me)];
  }

  @override
  Future<Review> addReview(Review review, {LatLng? checkInLocation}) async {
    try {
      final row = await _client
          .from('reviews')
          .insert({
            'spot_id': review.spotId,
            'wifi': review.wifi,
            'power': review.power,
            'quiet': review.quiet,
            'comfort': review.comfort,
            'crowd': review.crowd.name,
            'wifi_speed_mbps': review.wifiSpeedMbps,
            'comment': review.comment,
            'smoking': review.smoking?.name,
            'seating': review.seating?.name,
            'motor_parking': review.motorParking,
            'stay': review.stay?.name,
            'busy_times': [for (final t in review.busyTimes) t.name],
            // Hanya untuk menghitung check-in terverifikasi di server,
            // lalu langsung dibuang (tidak disimpan).
            if (checkInLocation != null)
              'checkin_location': 'SRID=4326;POINT('
                  '${checkInLocation.longitude} ${checkInLocation.latitude})',
          })
          .select(_reviewColumns)
          .single();
      return _reviewFromRow(row, _currentUserId);
    } on PostgrestException catch (e) {
      // 23505 = unique violation -> sudah review spot ini hari ini.
      if (e.code == '23505') throw const ReviewLimitException();
      rethrow;
    }
  }

  // ---- Konversi baris database -> model --------------------------------

  @visibleForTesting
  static Spot spotFromRow(Map<String, dynamic> row) => _spotFromRow(row);

  @visibleForTesting
  static Review reviewFromRow(Map<String, dynamic> row, String? me) =>
      _reviewFromRow(row, me);

  static Spot _spotFromRow(Map<String, dynamic> row) => Spot(
        id: row['id'] as String,
        name: row['name'] as String,
        area: row['area'] as String,
        address: row['address'] as String? ?? '',
        category: SpotCategory.values.byName(row['category'] as String),
        location: LatLng(
          (row['lat'] as num).toDouble(),
          (row['lng'] as num).toDouble(),
        ),
        openHour: row['open_hour'] as int?,
        closeHour: row['close_hour'] as int?,
        priceLevel: row['price_level'] as int?,
        description: row['description'] as String? ?? '',
        photos: [
          for (final p in (row['photos'] as List<dynamic>? ?? const [])) '$p',
        ],
      );

  static Review _reviewFromRow(Map<String, dynamic> row, String? me) => Review(
        id: row['id'] as String,
        spotId: row['spot_id'] as String,
        author: row['author_name'] as String? ?? 'Pengguna',
        wifi: row['wifi'] as int,
        power: row['power'] as int,
        quiet: row['quiet'] as int,
        comfort: row['comfort'] as int,
        crowd: CrowdLevel.values.byName(row['crowd'] as String),
        wifiSpeedMbps: (row['wifi_speed_mbps'] as num?)?.toDouble(),
        comment: row['comment'] as String? ?? '',
        // Waktu kunjungan dipakai untuk bobot kebaruan & "x hari lalu".
        createdAt: DateTime.parse(row['visited_at'] as String).toLocal(),
        verifiedCheckIn: row['verified_check_in'] as bool? ?? false,
        isMine: me != null && row['user_id'] == me,
        smoking: _enum(SmokingPolicy.values, row['smoking']),
        seating: _enum(Seating.values, row['seating']),
        motorParking: row['motor_parking'] as bool?,
        stay: _enum(StayPolicy.values, row['stay']),
        busyTimes: {
          for (final t in (row['busy_times'] as List<dynamic>? ?? const []))
            ?_enum(BusyTime.values, t),
        },
      );

  static T? _enum<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
