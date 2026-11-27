import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Input rating 1–5 bintang untuk satu aspek.
class RatingInput extends StatelessWidget {
  const RatingInput({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;

  /// 0 berarti belum diisi.
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                Text(
                  hint,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          for (var i = 1; i <= 5; i++)
            IconButton(
              tooltip: '$label $i',
              visualDensity: VisualDensity.compact,
              icon: Icon(i <= value ? Icons.star_rounded : Icons.star_outline_rounded),
              color: i <= value ? AppColors.orange : AppColors.line,
              onPressed: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}
