import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:spot_kerja/services/photo_processor.dart';

/// Membuat JPEG uji coba yang berisi lokasi GPS di EXIF, seperti foto dari HP.
Uint8List jpegWithGps({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 120, 40));
  image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational.list([
    img.Rational(8, 1),
    img.Rational(40, 1),
    img.Rational(3, 1),
  ]);
  image.exif.gpsIfd['GPSLongitude'] = img.IfdValueRational.list([
    img.Rational(115, 1),
    img.Rational(12, 1),
    img.Rational(57, 1),
  ]);
  image.exif.imageIfd['Make'] = 'KameraHP';
  return img.encodeJpg(image);
}

void main() {
  test('foto contoh benar-benar berisi GPS sebelum diproses', () {
    final original = img.decodeJpg(jpegWithGps(width: 400, height: 300))!;
    expect(original.exif.gpsIfd.isEmpty, isFalse);
  });

  test('metadata GPS & kamera dihapus', () {
    final result = PhotoProcessor.process(jpegWithGps(width: 400, height: 300))!;
    final decoded = img.decodeJpg(result)!;
    expect(decoded.exif.gpsIfd.isEmpty, isTrue);
    expect(decoded.exif.imageIfd['Make'], isNull);
  });

  test('foto besar dikecilkan, perbandingan sisi tetap', () {
    final result = PhotoProcessor.process(jpegWithGps(width: 4000, height: 3000))!;
    final decoded = img.decodeJpg(result)!;
    expect(decoded.width, PhotoProcessor.maxDimension);
    expect(decoded.height, 1200);
  });

  test('foto potret dikecilkan dari sisi tingginya', () {
    final result = PhotoProcessor.process(jpegWithGps(width: 1500, height: 3000))!;
    final decoded = img.decodeJpg(result)!;
    expect(decoded.height, PhotoProcessor.maxDimension);
    expect(decoded.width, 800);
  });

  test('foto kecil tidak diperbesar', () {
    final result = PhotoProcessor.process(jpegWithGps(width: 640, height: 480))!;
    expect(img.decodeJpg(result)!.width, 640);
  });

  test('file bukan gambar ditolak (null), tidak crash', () {
    expect(PhotoProcessor.process(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
}
