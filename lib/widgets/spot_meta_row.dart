import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/spot.dart';
import '../state/spot_store.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Satu baris info ringkas, dipisah titik:
///   harga · jarak · buka           (kartu besar)
///   ⚡ skor · buka · jarak           (kartu kecil, [scoreFirst] = true)
class SpotMetaRow extends StatelessWidget {
  const SpotMetaRow({
    super.key,
    required this.spot,
    this.scoreFirst = false,
    this.showPrice = true,
  });

  final Spot spot;
  final bool scoreFirst;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SpotStore>();
    final stats = store.statsFor(spot.id);
    final isOpen = spot.isOpenAt(DateTime.now());

    final rupiah = store.priceFor(spot);
    final price = _Meta(
      text: rupiah == null ? '' : '±${formatRupiahShort(rupiah)}',
      strong: true,
      suffix: ' /orang',
    );
    final distance = _Meta(
      icon: Icons.place_outlined,
      text: formatDistance(store.distanceTo(spot)),
    );
    final open = _Meta(
      icon: Icons.schedule_rounded,
      text: switch (isOpen) {
        true => 'Buka',
        false => 'Tutup',
        null => 'Jam ?',
      },
      color: switch (isOpen) {
        true => AppColors.success,
        false => AppColors.danger,
        null => null,
      },
    );
    final score = _Meta(
      icon: Icons.bolt_rounded,
      iconColor: AppColors.orange,
      text: stats.hasData ? '${stats.workScore}' : 'Baru',
      strong: true,
      suffix: stats.hasData ? ' (${stats.reviewCount})' : null,
    );

    final items = scoreFirst
        ? [score, open, distance]
        : [if (showPrice && rupiah != null) price, distance, open];

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            const Text('·', style: TextStyle(color: AppColors.muted)),
          items[i],
        ],
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.text,
    this.icon,
    this.iconColor,
    this.color,
    this.strong = false,
    this.suffix,
  });

  final String text;
  final IconData? icon;
  final Color? iconColor;
  final Color? color;
  final bool strong;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? (strong ? AppColors.ink : AppColors.muted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: iconColor ?? textColor),
          const SizedBox(width: 3),
        ],
        Text.rich(
          TextSpan(
            text: text,
            style: TextStyle(
              fontSize: 12.5,
              color: textColor,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
            children: [
              if (suffix != null)
                TextSpan(
                  text: suffix,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
