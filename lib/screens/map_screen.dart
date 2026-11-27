import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/spot_store.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_bar.dart';
import '../widgets/map_widgets.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/spot_cards.dart';

/// Tab "Peta": peta penuh, search bar di atas, dan bottom sheet daftar spot.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  /// Radius lingkaran "di sekitarmu" yang digambar di peta.
  static const nearbyRadiusMeters = 1500.0;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  late final _searchController =
      TextEditingController(text: context.read<SpotStore>().query);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const _initialZoom = 13.6;

  /// Bottom sheet menutupi bagian bawah peta, jadi titik yang ingin kita
  /// tonjolkan digeser [_liftPx] piksel ke atas dari tengah layar.
  static const _liftPx = 120.0;

  /// Pusat kamera supaya [target] tampil sedikit di atas tengah layar.
  /// (Pada Web Mercator, 1 piksel ≈ 360 / (256 · 2^zoom) derajat.)
  static LatLng _liftedCenter(LatLng target, double zoom) => LatLng(
        target.latitude - _liftPx * 360 / (256 * math.pow(2, zoom)),
        target.longitude,
      );

  Future<void> _goToMyLocation() async {
    final store = context.read<SpotStore>();
    final messenger = ScaffoldMessenger.of(context);
    await store.refreshLocation();
    if (!mounted) return;
    if (store.hasRealLocation) {
      _mapController.move(_liftedCenter(store.userLocation, 15), 15);
    } else {
      _mapController.move(
          _liftedCenter(SpotStore.defaultCenter, _initialZoom), _initialZoom);
      messenger.showSnackBar(const SnackBar(
        content: Text('Lokasi tidak tersedia. Menampilkan area contoh.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SpotStore>();
    final spots = store.visibleSpots;
    final center =
        store.hasRealLocation ? store.userLocation : SpotStore.defaultCenter;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
                _liftedCenter(SpotStore.defaultCenter, _initialZoom),
            initialZoom: _initialZoom,
          ),
          children: [
            appTileLayer(),
            NearbyRadiusLayer(
              center: center,
              radiusMeters: MapScreen.nearbyRadiusMeters,
            ),
            MarkerLayer(
              markers: [
                for (final spot in spots)
                  Marker(
                    point: spot.location,
                    width: ScoreMarker.width,
                    height: ScoreMarker.height,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => openSpotDetail(context, spot),
                      child: Tooltip(
                        message: spot.name,
                        child: ScoreMarker(stats: store.statsFor(spot.id)),
                      ),
                    ),
                  ),
                if (store.hasRealLocation)
                  Marker(
                    point: store.userLocation,
                    width: UserDot.size,
                    height: UserDot.size,
                    child: const UserDot(),
                  ),
              ],
            ),
            appMapAttribution(),
          ],
        ),

        // Search bar + tombol lokasi
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, 12, AppSpacing.page, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSmall),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: store.setQuery,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Cari tempat atau area…',
                      prefixIcon: Icon(Icons.search_rounded),
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                RoundIconButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Ke lokasiku',
                  color: AppColors.primary,
                  onPressed: _goToMyLocation,
                ),
              ],
            ),
          ),
        ),

        _NearbySheet(count: spots.length),
      ],
    );
  }
}

/// Bottom sheet yang bisa ditarik ke atas/bawah, berisi daftar spot.
class _NearbySheet extends StatelessWidget {
  const _NearbySheet({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SpotStore>();
    final spots = store.visibleSpots;

    return DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.14,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.34],
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, -2)),
          ],
        ),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page, 14, AppSpacing.page, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Spot di sekitarmu',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 2),
                              Text(
                                count == 0
                                    ? 'Tidak ada spot yang cocok dengan filter'
                                    : 'Ditemukan $count tempat',
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        RoundIconButton(
                          icon: Icons.tune_rounded,
                          tooltip: 'Filter & urutan',
                          bordered: true,
                          showDot: store.filter.isActive,
                          onPressed: () => showFilterSheet(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, 0, AppSpacing.page, 24),
              sliver: SliverList.separated(
                itemCount: spots.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => CompactSpotCard(spot: spots[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
