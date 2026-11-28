import 'package:flutter_test/flutter_test.dart';
import 'package:spot_kerja/data/supabase_spot_repository.dart';
import 'package:spot_kerja/models/place_facts.dart';
import 'package:spot_kerja/models/review.dart';
import 'package:spot_kerja/models/spot.dart';

/// Contoh baris JSON persis seperti yang dikirim PostgREST (Supabase).
void main() {
  test('baris spots_view -> Spot (jam & harga boleh kosong)', () {
    final spot = SupabaseSpotRepository.spotFromRow({
      'id': '5b0c1c1e-0000-4000-8000-000000000001',
      'name': 'Kopi Sawah',
      'area': 'Canggu',
      'address': '',
      'category': 'coworking',
      'lat': -8.6478,
      'lng': 115.1385,
      'open_hour': null,
      'close_hour': null,
      'price_level': null,
      'description': '',
      'photos': ['https://contoh.supabase.co/storage/v1/object/public/foto/1.jpg'],
      'created_at': '2026-11-28T03:00:00+00:00',
    });
    expect(spot.category, SpotCategory.coworking);
    expect(spot.location.latitude, -8.6478);
    expect(spot.hasHours, isFalse);
    expect(spot.isOpenAt(DateTime(2026, 11, 28, 10)), isNull);
    expect(spot.priceLevel, isNull);
    expect(spot.coverPhoto, startsWith('https://'));
  });

  test('lat/lng berupa angka bulat tetap terbaca', () {
    final spot = SupabaseSpotRepository.spotFromRow({
      'id': 'x', 'name': 'A', 'area': 'B', 'category': 'kafe',
      'lat': -8, 'lng': 115, 'open_hour': 8, 'close_hour': 22,
      'price_level': 2, 'photos': [],
    });
    expect(spot.location.longitude, 115.0);
    expect(spot.isOpenAt(DateTime(2026, 11, 28, 10)), isTrue);
  });

  test('baris reviews -> Review, termasuk atribut lokal & isMine', () {
    final row = {
      'id': 'r1',
      'spot_id': 's1',
      'user_id': 'user-abc',
      'author_name': 'Putu',
      'wifi': 5,
      'power': 4,
      'quiet': 3,
      'comfort': 4,
      'crowd': 'ramai',
      'wifi_speed_mbps': 48.5,
      'comment': 'Ramai saat sunset',
      'smoking': 'separateArea',
      'seating': 'both',
      'motor_parking': true,
      'stay': 'unlimited',
      'busy_times': ['sore', 'malam'],
      'verified_check_in': true,
      'visited_at': '2026-08-15T09:00:00+00:00',
    };
    final mine = SupabaseSpotRepository.reviewFromRow(row, 'user-abc');
    expect(mine.isMine, isTrue);
    expect(mine.crowd, CrowdLevel.ramai);
    expect(mine.wifiSpeedMbps, 48.5);
    expect(mine.smoking, SmokingPolicy.separateArea);
    expect(mine.busyTimes, {BusyTime.sore, BusyTime.malam});
    expect(mine.createdAt.toUtc(), DateTime.utc(2026, 8, 15, 9));

    expect(SupabaseSpotRepository.reviewFromRow(row, 'orang-lain').isMine,
        isFalse);
  });

  test('review data awal (tanpa user, atribut kosong)', () {
    final review = SupabaseSpotRepository.reviewFromRow({
      'id': 'r2', 'spot_id': 's1', 'user_id': null, 'author_name': 'Tim SpotKerja',
      'wifi': 3, 'power': 3, 'quiet': 3, 'comfort': 3, 'crowd': 'sedang',
      'wifi_speed_mbps': null, 'comment': '', 'smoking': null, 'seating': null,
      'motor_parking': null, 'stay': null, 'busy_times': [],
      'verified_check_in': false, 'visited_at': '2026-05-01T00:00:00+00:00',
    }, null);
    expect(review.isMine, isFalse);
    expect(review.wifiSpeedMbps, isNull);
    expect(review.busyTimes, isEmpty);
  });
}
