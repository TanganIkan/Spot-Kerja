import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Membungkus plugin geolocator.
///
/// Mengembalikan `null` (bukan error) kalau lokasi tidak tersedia,
/// sehingga app tetap jalan memakai lokasi default.
class LocationService {
  /// Batas waktu seluruh proses (cek izin + ambil posisi). Penting: dialog izin
  /// yang tidak dijawab user bisa menunggu selamanya tanpa batas ini.
  static const timeout = Duration(seconds: 10);

  static Future<LatLng?> currentPosition() =>
      _resolve().timeout(timeout, onTimeout: () => null);

  static Future<LatLng?> _resolve() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition();
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}
