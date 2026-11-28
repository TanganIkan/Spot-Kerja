import 'package:latlong2/latlong.dart';

/// Konfigurasi app yang diisi saat build lewat `--dart-define-from-file=env.json`.
///
/// Kalau kunci Supabase kosong, app otomatis berjalan dengan data contoh,
/// sehingga tetap bisa dicoba tanpa backend (misalnya oleh pengunjung
/// portfolio yang meng-clone repo).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get useSupabase =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Alamat kembali ke app setelah login Google (Android & iOS).
  /// Harus didaftarkan juga di Supabase: Authentication -> URL Configuration.
  static const authRedirectMobile = 'com.spotkerja.app://login-callback';

  /// Titik tengah default untuk data Bali (antara Denpasar & Canggu).
  static final baliCenter = LatLng(-8.6650, 115.1800);
  static const baliAreaName = 'Bali';
}
