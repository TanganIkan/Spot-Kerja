import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/spot.dart';
import '../screens/spot_detail_screen.dart';
import '../state/favorites_store.dart';
import '../state/spot_store.dart';
import '../theme/app_theme.dart';
import 'score_pill.dart';
import 'spot_meta_row.dart';
import 'spot_photo.dart';

void openSpotDetail(BuildContext context, Spot spot) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => SpotDetailScreen(spotId: spot.id),
  ));
}

/// Kartu besar berfoto untuk carousel "Spot terdekat".
class NearbySpotCard extends StatelessWidget {
  const NearbySpotCard({super.key, required this.spot, this.width = 270});

  final Spot spot;
  final double width;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SpotStore>();
    final stats = store.statsFor(spot.id);
    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: AppColors.line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openSpotDetail(context, spot),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SpotPhoto(
                    path: store.coverPhotoFor(spot),
                    height: 150,
                    width: width,
                  ),
                  Positioned(top: 10, right: 10, child: ScorePill(stats: stats)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      spot.fullAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    // Satu baris saja; kalau teks sistem diperbesar,
                    // baris ini mengecil alih-alih meluber keluar kartu.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SpotMetaRow(spot: spot),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu kecil (thumbnail di kiri) untuk daftar rekomendasi, peta, & tersimpan.
class CompactSpotCard extends StatelessWidget {
  const CompactSpotCard({super.key, required this.spot, this.showBookmark = false});

  final Spot spot;
  final bool showBookmark;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesStore>();
    final store = context.watch<SpotStore>();
    final saved = favorites.isFavorite(spot.id);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: AppColors.line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openSpotDetail(context, spot),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SpotPhoto(
                  path: store.coverPhotoFor(spot),
                  width: 84,
                  height: 84,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${spot.category.label} · ${spot.area}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted),
                      ),
                      const SizedBox(height: 10),
                      SpotMetaRow(spot: spot, scoreFirst: true),
                    ],
                  ),
                ),
                if (showBookmark)
                  IconButton(
                    tooltip: saved ? 'Hapus dari tersimpan' : 'Simpan',
                    icon: Icon(saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded),
                    color: saved ? AppColors.primary : AppColors.muted,
                    onPressed: () => favorites.toggle(spot.id),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
