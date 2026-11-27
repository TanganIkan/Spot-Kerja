import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/favorites_store.dart';
import '../state/spot_store.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/spot_cards.dart';

/// Tab "Tersimpan": spot yang di-bookmark user (tidak terpengaruh filter).
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SpotStore>();
    final favorites = context.watch<FavoritesStore>();
    final spots =
        store.allSpots.where((s) => favorites.isFavorite(s.id)).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, 16, AppSpacing.page, 4),
            child: Text('Tersimpan',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Text(
              spots.isEmpty
                  ? 'Simpan spot favoritmu supaya mudah ditemukan lagi.'
                  : '${spots.length} spot tersimpan',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: store.isLoading
                ? const Center(child: CircularProgressIndicator())
                : spots.isEmpty
                    ? const EmptyState(
                        icon: Icons.bookmark_border_rounded,
                        title: 'Belum ada yang disimpan',
                        message: 'Tekan ikon bookmark di halaman detail '
                            'spot untuk menyimpannya di sini.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.page, 4, AppSpacing.page, 24),
                        itemCount: spots.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) => CompactSpotCard(
                            spot: spots[i], showBookmark: true),
                      ),
          ),
        ],
      ),
    );
  }
}
