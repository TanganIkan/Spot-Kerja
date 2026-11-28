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

  /// Nama bucket Supabase Storage untuk foto user.
  static const photoBucket = 'spot-photos';

  /// Ambil semua kolom yang ADA. Kalau migrasi terbaru belum dijalankan,
  /// kolom barunya cukup dianggap kosong, bukan membuat app gagal memuat.
  static const _reviewColumns = '*';

  /// Review + foto-fotonya (relasi spot_photos.review_id -> reviews.id).
  static const _reviewWithPhotos = '*, spot_photos(storage_path, created_at)';

  String? get _currentUserId => _client.auth.currentUser?.id;

  String _publicUrl(String path) =>
      _client.storage.from(photoBucket).getPublicUrl(path);

  @override
  bool get supportsPhotos => true;

  @override
  Future<List<Spot>> fetchSpots() async {
    final rows = await _client.from('spots_view').select();
    return [for (final row in rows) _spotFromRow(row)];
  }

  @override
  Future<List<Review>> fetchReviews() async {
    final me = _currentUserId;
    try {
      final rows = await _client
          .from('reviews')
          .select(_reviewWithPhotos)
          .order('visited_at', ascending: false)
          .limit(maxReviews);
      return [
        for (final row in rows) _reviewFromRow(row, me, photoUrl: _publicUrl),
      ];
    } on PostgrestException catch (e) {
      // PGRST200 = tabel spot_photos belum ada (migrasi foto belum
      // dijalankan). Review tetap dimuat, hanya tanpa foto.
      if (e.code != 'PGRST200') rethrow;
      final rows = await _client
          .from('reviews')
          .select(_reviewColumns)
          .order('visited_at', ascending: false)
          .limit(maxReviews);
      return [for (final row in rows) _reviewFromRow(row, me)];
    }
  }

  @override
  Future<Review> addReview(
    Review review, {
    LatLng? checkInLocation,
    List<Uint8List> photos = const [],
  }) async {
    final Review saved;
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
            // Kolom dari migrasi yang lebih baru: hanya dikirim kalau diisi,
            // supaya review tetap bisa dikirim walau migrasinya belum jalan.
            if (review.spendPerPerson != null)
              'spend_per_person': review.spendPerPerson,
            // Hanya untuk menghitung check-in terverifikasi di server,
            // lalu langsung dibuang (tidak disimpan).
            if (checkInLocation != null)
              'checkin_location': 'SRID=4326;POINT('
                  '${checkInLocation.longitude} ${checkInLocation.latitude})',
          })
          .select(_reviewColumns)
          .single();
      saved = _reviewFromRow(row, _currentUserId);
    } on PostgrestException catch (e) {
      // 23505 = unique violation -> sudah review spot ini hari ini.
      if (e.code == '23505') throw const ReviewLimitException();
      rethrow;
    }

    // Review sudah tersimpan. Foto diunggah satu per satu; kalau ada yang
    // gagal, review tetap tersimpan dengan foto yang berhasil saja.
    final urls = <String>[];
    final userId = _currentUserId;
    if (userId == null) return saved;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < photos.length; i++) {
      // Folder pertama = id user (diwajibkan aturan storage di database).
      final path = '$userId/${saved.id}/$stamp-$i.jpg';
      final bucket = _client.storage.from(photoBucket);
      try {
        await bucket.uploadBinary(
          path,
          photos[i],
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      } catch (_) {
        continue;
      }
      try {
        await _client.from('spot_photos').insert({
          'spot_id': review.spotId,
          'review_id': saved.id,
          'storage_path': path,
        });
        urls.add(_publicUrl(path));
      } catch (_) {
        // Catatan gagal disimpan: hapus file-nya supaya tidak jadi sampah.
        await bucket.remove([path]).catchError((_) => <FileObject>[]);
      }
    }
    return saved.withPhotos(urls);
  }

  // ---- Konversi baris database -> model --------------------------------

  @visibleForTesting
  static Spot spotFromRow(Map<String, dynamic> row) => _spotFromRow(row);

  @visibleForTesting
  static Review reviewFromRow(
    Map<String, dynamic> row,
    String? me, {
    String Function(String path)? photoUrl,
  }) =>
      _reviewFromRow(row, me, photoUrl: photoUrl);

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
        avgPrice: row['avg_price'] as int?,
        description: row['description'] as String? ?? '',
        photos: [
          for (final p in (row['photos'] as List<dynamic>? ?? const [])) '$p',
        ],
      );

  static Review _reviewFromRow(
    Map<String, dynamic> row,
    String? me, {
    String Function(String path)? photoUrl,
  }) =>
      Review(
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
        photoUrls: photoUrl == null ? const [] : _photoUrls(row, photoUrl),
        spendPerPerson: row['spend_per_person'] as int?,
      );

  /// Foto dari relasi spot_photos, urut dari yang paling lama diunggah.
  static List<String> _photoUrls(
    Map<String, dynamic> row,
    String Function(String path) photoUrl,
  ) {
    final photos = [
      for (final p in (row['spot_photos'] as List<dynamic>? ?? const []))
        p as Map<String, dynamic>,
    ]..sort((a, b) =>
        (a['created_at'] as String? ?? '').compareTo(b['created_at'] as String? ?? ''));
    return [for (final p in photos) photoUrl(p['storage_path'] as String)];
  }

  static T? _enum<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
