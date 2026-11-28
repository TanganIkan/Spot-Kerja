import 'package:latlong2/latlong.dart';

/// Jenis tempat, dipakai untuk chip kategori di Beranda.
enum SpotCategory { kafe, coworking, roastery }

extension SpotCategoryLabel on SpotCategory {
  String get label => switch (this) {
        SpotCategory.kafe => 'Kafe',
        SpotCategory.coworking => 'Co-working',
        SpotCategory.roastery => 'Roastery',
      };
}

/// Data tetap sebuah tempat kerja (kafe / co-working).
///
/// Data yang sering berubah (WiFi, keramaian, rating) TIDAK disimpan di sini,
/// tapi dihitung dari review — lihat [SpotStats].
class Spot {
  const Spot({
    required this.id,
    required this.name,
    required this.area,
    required this.address,
    required this.location,
    required this.category,
    this.openHour,
    this.closeHour,
    this.priceLevel,
    this.photos = const [],
    this.description = '',
  });

  final SpotCategory category;

  /// Path asset atau URL foto. Foto pertama dipakai sebagai cover.
  final List<String> photos;

  String? get coverPhoto => photos.isEmpty ? null : photos.first;

  final String id;
  final String name;

  /// Nama area / kecamatan, dipakai juga untuk pencarian.
  final String area;
  final String address;
  final LatLng location;

  /// Jam buka (0–23). null = belum diketahui.
  final int? openHour;

  /// Jam tutup (1–24). 24 berarti tutup tengah malam / buka 24 jam.
  /// null = belum diketahui.
  final int? closeHour;

  /// 1 = hemat, 2 = sedang, 3 = premium. null = belum diketahui.
  final int? priceLevel;
  final String description;

  bool get hasHours => openHour != null && closeHour != null;

  /// true = buka, false = tutup, null = jam buka belum diketahui.
  bool? isOpenAt(DateTime time) {
    if (!hasHours) return null;
    return time.hour >= openHour! && time.hour < closeHour!;
  }

  /// Masuk filter "Buka malam" kalau tutup jam 22.00 atau lebih.
  bool get opensLate => (closeHour ?? 0) >= 22;

  bool get isOpen24Hours => openHour == 0 && closeHour == 24;

  String get hoursLabel {
    if (!hasHours) return 'Jam buka belum diketahui';
    if (isOpen24Hours) return 'Buka 24 jam';
    String two(int h) => h.toString().padLeft(2, '0');
    return '${two(openHour!)}.00 – ${two(closeHour!)}.00';
  }
}
