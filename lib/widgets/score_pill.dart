import 'package:material_ui/material_ui.dart';

import '../models/spot_stats.dart';
import '../theme/app_theme.dart';

/// Pill putih kecil berisi Work Score, contoh: "⚡ 80 (2)".
/// Dipakai di atas foto kartu.
class ScorePill extends StatelessWidget {
  const ScorePill({super.key, required this.stats});

  final SpotStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 16, color: AppColors.orange),
          const SizedBox(width: 2),
          Text(
            stats.hasData ? '${stats.workScore}' : 'Baru',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.ink,
            ),
          ),
          if (stats.hasData)
            Text(
              ' (${stats.reviewCount})',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}
