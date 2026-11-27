import 'package:material_ui/material_ui.dart';

import '../utils/format.dart';

/// Lingkaran berisi Work Score, warnanya mengikuti tinggi-rendahnya skor.
class WorkScoreBadge extends StatelessWidget {
  const WorkScoreBadge({
    super.key,
    required this.score,
    required this.hasData,
    this.size = 52,
  });

  final int score;
  final bool hasData;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(score, hasData: hasData);
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.alphaBlend(color.withValues(alpha: 0.14), surface),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        hasData ? '$score' : '–',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
