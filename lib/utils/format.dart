import 'package:material_ui/material_ui.dart';

String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

String timeAgo(DateTime time, [DateTime? now]) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
  if (diff.inDays < 1) return '${diff.inHours} jam lalu';
  if (diff.inDays < 30) return '${diff.inDays} hari lalu';
  return '${diff.inDays ~/ 30} bulan lalu';
}

/// 25000 -> "25rb", 27500 -> "28rb", 1250000 -> "1,3jt".
String formatRupiahShort(int rupiah) {
  if (rupiah >= 1000000) {
    final juta = (rupiah / 100000).round() / 10;
    return '${juta.toString().replaceAll('.0', '').replaceAll('.', ',')}jt';
  }
  return '${(rupiah / 1000).round()}rb';
}

String scoreLabel(int score, {required bool hasData}) {
  if (!hasData) return 'Belum ada data';
  if (score >= 80) return 'Sangat cocok untuk kerja';
  if (score >= 60) return 'Cukup untuk kerja';
  return 'Kurang ideal untuk kerja lama';
}

Color scoreColor(int score, {required bool hasData}) {
  if (!hasData) return Colors.grey.shade600;
  if (score >= 80) return const Color(0xFF2E7D32);
  if (score >= 60) return const Color(0xFFB26A00);
  return const Color(0xFFC62828);
}

/// Batas wajar laporan pengeluaran per orang.
const minSpendRupiah = 1000;
const maxSpendRupiah = 1000000;

/// "35000", "35.000", "35rb", "35 ribu", "35k" -> 35000. Tidak valid -> null.
int? parseRupiah(String input) {
  final text = input.trim().toLowerCase().replaceAll('rp', '').replaceAll(' ', '');
  if (text.isEmpty) return null;
  final short = RegExp(r'^(\d+(?:[.,]\d+)?)(rb|ribu|k)$').firstMatch(text);
  if (short != null) {
    final number = double.tryParse(short.group(1)!.replaceAll(',', '.'));
    return number == null ? null : (number * 1000).round();
  }
  // Titik / koma sebagai pemisah ribuan: "35.000" atau "35,000"
  if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(text) || RegExp(r'^\d+$').hasMatch(text)) {
    return int.tryParse(text.replaceAll(RegExp(r'[.,]'), ''));
  }
  return null;
}
