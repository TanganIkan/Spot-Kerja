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

String priceLabel(int? level) => switch (level) {
      1 => '< 30rb',
      2 => '30–60rb',
      3 => '> 60rb',
      _ => '–',
    };

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
