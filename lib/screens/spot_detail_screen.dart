import 'package:flutter_map/flutter_map.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/place_facts.dart';
import '../models/review.dart';
import '../models/spot.dart';
import '../models/spot_stats.dart';
import '../state/favorites_store.dart';
import '../state/spot_store.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/map_widgets.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/spot_meta_row.dart';
import '../widgets/spot_photo.dart';
import '../widgets/work_score_badge.dart';
import 'review_form_screen.dart';

/// Detail spot: galeri foto, info, Work Score, kondisi terkini, lokasi, review.
class SpotDetailScreen extends StatelessWidget {
  const SpotDetailScreen({super.key, required this.spotId});

  final String spotId;

  /// Data keramaian dianggap "masih baru" kalau dilaporkan < 3 jam lalu.
  static const freshCrowdWindow = Duration(hours: 3);

  static Future<void> openDirections(Spot spot) => launchUrl(
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination='
          '${spot.location.latitude},${spot.location.longitude}',
        ),
        mode: LaunchMode.externalApplication,
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SpotStore>();
    final spot = store.spotById(spotId);

    if (spot == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Spot tidak ditemukan.')),
      );
    }

    final stats = store.statsFor(spot.id);
    final reviews = store.reviewsFor(spot.id);
    final theme = Theme.of(context);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _PhotoHeader(spot: spot),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, 20, AppSpacing.page, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spot.name,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 22)),
                const SizedBox(height: 4),
                Text('${spot.address}, ${spot.area}',
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                SpotMetaRow(spot: spot),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(),
                ),
                const _SectionTitle('Tentang tempat ini'),
                Text(
                  spot.description,
                  style: const TextStyle(color: AppColors.muted, height: 1.55),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Tag(icon: Icons.category_outlined, text: spot.category.label),
                    _Tag(icon: Icons.schedule_rounded, text: spot.hoursLabel),
                    _Tag(
                      icon: Icons.near_me_outlined,
                      text: '${formatDistance(store.distanceTo(spot))} dari '
                          '${store.hasRealLocation ? 'lokasimu' : 'pusat area'}',
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const _SectionTitle('Kondisi untuk kerja'),
                _WorkScoreCard(stats: stats),
                const SizedBox(height: 12),
                _LiveStats(stats: stats),
                const SizedBox(height: 28),
                const _SectionTitle('Fasilitas & aturan'),
                _PlaceFactsSection(facts: stats.facts),
                const SizedBox(height: 28),
                const _SectionTitle('Lokasi'),
                _MiniMap(spot: spot, stats: stats),
                const SizedBox(height: 28),
                _SectionTitle('Review (${reviews.length})'),
                if (reviews.isEmpty)
                  const Text('Belum ada review. Jadilah yang pertama!',
                      style: TextStyle(color: AppColors.muted)),
                for (final r in reviews) _ReviewTile(review: r),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, 12, AppSpacing.page, 12),
            child: FilledButton.icon(
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Check-in & Review'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReviewFormScreen(spotId: spot.id),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Galeri foto yang bisa digeser + tombol kembali & simpan.
class _PhotoHeader extends StatefulWidget {
  const _PhotoHeader({required this.spot});

  final Spot spot;

  @override
  State<_PhotoHeader> createState() => _PhotoHeaderState();
}

class _PhotoHeaderState extends State<_PhotoHeader> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.spot.photos.isEmpty
        ? <String?>[null]
        : widget.spot.photos.cast<String?>();
    final favorites = context.watch<FavoritesStore>();
    final saved = favorites.isFavorite(widget.spot.id);

    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) =>
                SpotPhoto(path: photos[i], height: 320, width: double.infinity),
          ),
          if (photos.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < photos.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page, vertical: 8),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  RoundIconButton(
                    icon: saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    tooltip: saved ? 'Hapus dari tersimpan' : 'Simpan',
                    color: saved ? AppColors.primary : AppColors.ink,
                    onPressed: () => favorites.toggle(widget.spot.id),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primaryText),
            const SizedBox(width: 5),
            Text(text,
                style: const TextStyle(fontSize: 12.5, color: AppColors.ink)),
          ],
        ),
      );
}

class _WorkScoreCard extends StatelessWidget {
  const _WorkScoreCard({required this.stats});

  final SpotStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              WorkScoreBadge(
                  score: stats.workScore, hasData: stats.hasData, size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WORK SCORE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      scoreLabel(stats.workScore, hasData: stats.hasData),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      stats.hasData
                          ? 'Dari ${stats.reviewCount} review · review terbaru berbobot lebih besar'
                          : 'Skor muncul setelah ada review pertama',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stats.hasData) ...[
            const SizedBox(height: 16),
            _AspectBar(icon: Icons.wifi_rounded, label: 'WiFi', value: stats.wifi),
            _AspectBar(icon: Icons.power_rounded, label: 'Colokan', value: stats.power),
            _AspectBar(
                icon: Icons.volume_off_outlined,
                label: 'Ketenangan',
                value: stats.quiet),
            _AspectBar(
                icon: Icons.chair_outlined,
                label: 'Kenyamanan',
                value: stats.comfort),
          ],
        ],
      ),
    );
  }
}

class _AspectBar extends StatelessWidget {
  const _AspectBar({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 17, color: AppColors.muted),
            const SizedBox(width: 8),
            SizedBox(
              width: 86,
              child: Text(label, style: const TextStyle(fontSize: 13.5)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: value / 5, minHeight: 7),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 26,
              child: Text(
                value.toStringAsFixed(1),
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

/// Dua kotak: kecepatan WiFi & keramaian terakhir.
class _LiveStats extends StatelessWidget {
  const _LiveStats({required this.stats});

  final SpotStats stats;

  @override
  Widget build(BuildContext context) {
    final crowdAt = stats.latestCrowdAt;
    final crowdStale = crowdAt != null &&
        DateTime.now().difference(crowdAt) > SpotDetailScreen.freshCrowdWindow;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.speed_rounded,
            label: 'Kecepatan WiFi',
            value: stats.wifiSpeedMbps == null
                ? '—'
                : '${stats.wifiSpeedMbps!.round()} Mbps',
            caption: stats.wifiMeasuredAt == null
                ? 'Belum ada speed test'
                : 'diukur ${timeAgo(stats.wifiMeasuredAt!)}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.groups_outlined,
            label: 'Keramaian',
            value: stats.latestCrowd?.label ?? '—',
            caption: crowdAt == null
                ? 'Belum ada laporan'
                : '${timeAgo(crowdAt)}${crowdStale ? ' · mungkin berubah' : ''}',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.sand.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.primaryText),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            Text(value,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(caption,
                maxLines: 2,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ],
        ),
      );
}

/// Peta kecil (tidak bisa digeser) + tombol "Buka di Google Maps".
class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.spot, required this.stats});

  final Spot spot;
  final SpotStats stats;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: SizedBox(
        height: 160,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: spot.location,
                initialZoom: 15.5,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                appTileLayer(),
                MarkerLayer(markers: [
                  Marker(
                    point: spot.location,
                    width: ScoreMarker.width,
                    height: ScoreMarker.height,
                    alignment: Alignment.topCenter,
                    child: ScoreMarker(stats: stats),
                  ),
                ]),
              ],
            ),
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Center(
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  elevation: 2,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => SpotDetailScreen.openDirections(spot),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_rounded,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Buka di Google Maps',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 12.5, color: AppColors.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.sand.withValues(alpha: 0.7),
                foregroundColor: AppColors.primaryText,
                child: Text(review.author[0],
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(review.author,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        if (review.verifiedCheckIn) ...[
                          const SizedBox(width: 4),
                          const Tooltip(
                            message: 'Check-in terverifikasi di lokasi',
                            child: Icon(Icons.verified_rounded,
                                size: 16, color: AppColors.primary),
                          ),
                        ],
                      ],
                    ),
                    Text(
                        '${timeAgo(review.createdAt)} · ${review.crowd.label}',
                        style: muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniRating('WiFi', review.wifi),
              _MiniRating('Colokan', review.power),
              _MiniRating('Tenang', review.quiet),
              _MiniRating('Nyaman', review.comfort),
              if (review.wifiSpeedMbps != null)
                _MiniRating('${review.wifiSpeedMbps!.round()} Mbps', null),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment, style: const TextStyle(height: 1.45)),
          ],
          const SizedBox(height: 10),
          const Divider(),
        ],
      ),
    );
  }
}

class _MiniRating extends StatelessWidget {
  const _MiniRating(this.label, this.value);

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value == null ? label : '$label $value',
          style: const TextStyle(fontSize: 12, color: AppColors.ink),
        ),
      );
}

/// Atribut lokal: rokok, tempat duduk, parkir motor, duduk lama, jam ramai.
class _PlaceFactsSection extends StatelessWidget {
  const _PlaceFactsSection({required this.facts});

  final PlaceFacts facts;

  @override
  Widget build(BuildContext context) {
    final parking = switch (facts.motorParking) {
      true => 'Mudah',
      false => 'Sulit',
      null => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _FactTile(
                  width: tileWidth,
                  icon: Icons.smoke_free_rounded,
                  label: 'Rokok',
                  value: facts.smoking?.label,
                  good: facts.hasSmokeFreeRoom,
                ),
                _FactTile(
                  width: tileWidth,
                  icon: Icons.ac_unit_rounded,
                  label: 'Tempat duduk',
                  value: facts.seating?.label,
                  good: facts.hasAc,
                ),
                _FactTile(
                  width: tileWidth,
                  icon: Icons.two_wheeler_rounded,
                  label: 'Parkir motor',
                  value: parking,
                  good: facts.motorParking == true,
                ),
                _FactTile(
                  width: tileWidth,
                  icon: Icons.hourglass_bottom_rounded,
                  label: 'Duduk lama',
                  value: facts.stay?.label,
                  good: facts.allowsLongStay,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.groups_outlined,
                      size: 20, color: AppColors.primaryText),
                  SizedBox(width: 10),
                  Text('Biasanya ramai',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: facts.busyTimes.isEmpty
                    ? const Text('Belum ada info',
                        style: TextStyle(color: AppColors.muted))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in BusyTime.values)
                            if (facts.busyTimes.contains(t))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.sand.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(t.icon,
                                        size: 14,
                                        color: AppColors.primaryText),
                                    const SizedBox(width: 4),
                                    Text(t.label,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          facts.hasData
              ? 'Berdasarkan ${facts.reportCount} laporan pengunjung · suara terbanyak, '
                  'laporan terbaru berbobot lebih besar'
              : 'Belum ada laporan. Bantu isi lewat Check-in & Review.',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.good,
  });

  final double width;
  final IconData icon;
  final String label;

  /// null = belum ada info.
  final String? value;

  /// True kalau nilainya "positif" untuk pekerja (ikon diberi warna hijau).
  final bool good;

  @override
  Widget build(BuildContext context) {
    final known = value != null;
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: !known
                  ? AppColors.surfaceSoft
                  : good
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.sand.withValues(alpha: 0.6),
            ),
            child: Icon(
              icon,
              size: 18,
              color: !known
                  ? AppColors.muted
                  : good
                      ? AppColors.success
                      : AppColors.primaryText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                Text(
                  value ?? 'Belum ada info',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: known ? FontWeight.w600 : FontWeight.w400,
                    color: known ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
