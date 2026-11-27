import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/spot.dart';
import '../state/spot_store.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_bar.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/spot_cards.dart';

/// "Lihat semua": pencarian + filter + daftar lengkap spot.
class AllSpotsScreen extends StatefulWidget {
  const AllSpotsScreen({super.key, this.category});

  /// Kalau diisi, hanya tampilkan kategori ini.
  final SpotCategory? category;

  @override
  State<AllSpotsScreen> createState() => _AllSpotsScreenState();
}

class _AllSpotsScreenState extends State<AllSpotsScreen> {
  late final _searchController =
      TextEditingController(text: context.read<SpotStore>().query);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SpotStore>();
    final spots = store.visibleSpots
        .where((s) => widget.category == null || s.category == widget.category)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null
            ? 'Semua spot'
            : 'Spot ${widget.category!.label}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, 4, AppSpacing.page, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: store.setQuery,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Cari nama tempat atau area…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                RoundIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Filter & urutan',
                  bordered: true,
                  size: 50,
                  showDot: store.filter.isActive,
                  onPressed: () => showFilterSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const FilterBar(),
          Expanded(
            child: spots.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Tidak ada spot yang cocok',
                    message: 'Coba kurangi filter atau ganti kata pencarian.',
                    actionLabel: store.filter.isActive ? 'Reset filter' : null,
                    onAction: () => store.setFilter(store.filter.cleared()),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page, 8, AppSpacing.page, 24),
                    itemCount: spots.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        CompactSpotCard(spot: spots[i], showBookmark: true),
                  ),
          ),
        ],
      ),
    );
  }
}
