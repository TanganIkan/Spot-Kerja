import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/spot.dart';
import '../models/spot_filter.dart';
import '../state/spot_store.dart';
import '../theme/app_theme.dart';
import '../widgets/category_tabs.dart';
import '../widgets/empty_state.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/section_header.dart';
import '../widgets/spot_cards.dart';
import 'all_spots_screen.dart';

/// Tab "Beranda": sapaan, shortcut ke peta, spot terdekat, dan rekomendasi.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.onOpenMap});

  final VoidCallback onOpenMap;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  /// null = "Semua".
  SpotCategory? _category;

  static const nearbyCount = 6;
  static const recommendationCount = 5;

  void _openAll({required SortBy sortBy, SpotCategory? category}) {
    final store = context.read<SpotStore>();
    store.setFilter(store.filter.copyWith(sortBy: sortBy));
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AllSpotsScreen(category: category),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SpotStore>();

    return SafeArea(
      bottom: false,
      child: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : store.error != null
              ? EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Terjadi kesalahan',
                  message: store.error!,
                  actionLabel: 'Coba lagi',
                  onAction: store.load,
                )
              : _buildContent(context, store),
    );
  }

  Widget _buildContent(BuildContext context, SpotStore store) {
    final nearby = [...store.allSpots]
      ..sort((a, b) => store.distanceTo(a).compareTo(store.distanceTo(b)));

    final recommended = store.allSpots
        .where((s) => _category == null || s.category == _category)
        .toList()
      ..sort((a, b) =>
          store.statsFor(b.id).workScore.compareTo(store.statsFor(a.id).workScore));

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Header(store: store),
        const SizedBox(height: 20),
        _MapShortcut(onTap: widget.onOpenMap),
        const SizedBox(height: 28),
        SectionHeader(
          title: 'Spot terdekat',
          onSeeAll: () => _openAll(sortBy: SortBy.distance),
        ),
        const SizedBox(height: 8),
        SizedBox(
          // Foto 150 + area teks yang ikut membesar sesuai ukuran teks sistem.
          height: 150 + MediaQuery.textScalerOf(context).scale(112),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            itemCount: nearby.take(nearbyCount).length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) => NearbySpotCard(spot: nearby[i]),
          ),
        ),
        const SizedBox(height: 28),
        SectionHeader(
          title: 'Rekomendasi untuk kerja',
          onSeeAll: () =>
              _openAll(sortBy: SortBy.workScore, category: _category),
        ),
        const SizedBox(height: 8),
        CategoryTabs<SpotCategory?>(
          options: const [null, ...SpotCategory.values],
          selected: _category,
          labelOf: (c) => c?.label ?? 'Semua',
          onSelected: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 14),
        if (recommended.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.page),
            child: Text('Belum ada spot di kategori ini.',
                style: TextStyle(color: AppColors.muted)),
          ),
        for (final spot in recommended.take(recommendationCount))
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, 0, AppSpacing.page, 12),
            child: CompactSpotCard(spot: spot),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.store});

  final SpotStore store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      store.hasRealLocation
                          ? Icons.place_rounded
                          : Icons.place_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        store.hasRealLocation
                            ? 'Lokasimu saat ini'
                            : '${SpotStore.defaultAreaName} (area contoh)',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Temukan spot kerja',
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          RoundIconButton(
            icon: store.hasRealLocation
                ? Icons.my_location_rounded
                : Icons.location_disabled_outlined,
            tooltip: store.hasRealLocation
                ? 'Perbarui lokasi'
                : 'Aktifkan lokasi',
            color: store.hasRealLocation ? AppColors.primary : AppColors.ink,
            bordered: true,
            onPressed: store.isLocating ? null : store.refreshLocation,
          ),
        ],
      ),
    );
  }
}

/// Kartu "Cari lewat peta" dengan pola garis seperti peta di latarnya.
class _MapShortcut extends StatelessWidget {
  const _MapShortcut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: CustomPaint(
          painter: _MapPatternPainter(),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              elevation: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                onTap: onTap,
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSmall),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map_outlined, color: AppColors.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Cari tempat lewat peta',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF3F2F5),
    );
    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    canvas
      ..drawLine(Offset(-10, h * 0.25), Offset(w + 10, h * 0.05), road)
      ..drawLine(Offset(w * 0.18, -10), Offset(w * 0.32, h + 10), road)
      ..drawLine(Offset(w * 0.62, -10), Offset(w * 0.55, h + 10), road)
      ..drawLine(Offset(-10, h * 0.85), Offset(w + 10, h * 0.7), road);
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(Offset(w * 0.85, h * 0.4), h * 0.35, ring);
    canvas.drawCircle(
      Offset(w * 0.85, h * 0.4),
      5,
      Paint()..color = AppColors.peach,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
