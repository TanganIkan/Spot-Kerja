import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Menyiapkan foto user sebelum diunggah:
///   1. memutar foto sesuai orientasi kamera,
///   2. mengecilkan ke sisi terpanjang [maxDimension] piksel,
///   3. MENGHAPUS SEMUA METADATA (EXIF), termasuk lokasi GPS tempat foto
///      diambil, yang bisa membocorkan alamat rumah user,
///   4. menyimpan ulang sebagai JPEG berkualitas [jpegQuality].
class PhotoProcessor {
  static const maxDimension = 1600;
  static const jpegQuality = 80;

  /// Batas ukuran file asli yang mau diproses (sebelum dikecilkan).
  static const maxInputBytes = 25 * 1024 * 1024;

  /// Hasil JPEG yang sudah bersih, atau `null` kalau file bukan gambar
  /// yang bisa dibaca (misalnya format HEIC yang belum didukung).
  static Uint8List? process(Uint8List input) {
    if (input.lengthInBytes > maxInputBytes) return null;
    final decoded = img.decodeImage(input);
    if (decoded == null) return null;

    var image = img.bakeOrientation(decoded);
    if (image.width > maxDimension || image.height > maxDimension) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxDimension)
          : img.copyResize(image, height: maxDimension);
    }
    image.exif = img.ExifData(); // buang semua metadata
    return img.encodeJpg(image, quality: jpegQuality);
  }

  /// Versi asinkron: di Android/iOS diproses di isolate terpisah supaya UI
  /// tidak tersendat. (Di web, compute tetap berjalan di thread utama.)
  static Future<Uint8List?> processAsync(Uint8List input) =>
      compute(process, input);
}
