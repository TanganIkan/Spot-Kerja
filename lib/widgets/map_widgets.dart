import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/spot_stats.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Filter warna: ubah tile OSM yang berwarna-warni menjadi abu-abu terang,
/// supaya peta kalem dan marker oranye lebih menonjol.
///   hasil = 55% versi grayscale + 45% putih
const _mutedMapFilter = ColorFilter.matrix(<double>[
  0.117, 0.393, 0.040, 0, 115, //
  0.117, 0.393, 0.040, 0, 115, //
  0.117, 0.393, 0.040, 0, 117, //
  0, 0, 0, 1, 0, //
]);

/// Tile peta OpenStreetMap (gratis, tanpa API key) dengan gaya kalem.
TileLayer appTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.spotkerja.app',
      tileBuilder: (context, tileWidget, tile) =>
          ColorFiltered(colorFilter: _mutedMapFilter, child: tileWidget),
    );

/// Atribusi wajib untuk data & tile OpenStreetMap.
Widget appMapAttribution() => RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          onTap: () =>
              launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
        ),
      ],
    );

/// Marker berbentuk pill berisi Work Score, dengan "ekor" kecil ke bawah.
class ScoreMarker extends StatelessWidget {
  const ScoreMarker({super.key, required this.stats});

  static const width = 66.0;
  static const height = 42.0;

  final SpotStats stats;

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(stats.workScore, hasData: stats.hasData);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(7, 5, 10, 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, size: 15, color: color),
              Text(
                stats.hasData ? '${stats.workScore}' : 'Baru',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        CustomPaint(size: const Size(12, 6), painter: _TailPainter()),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Titik posisi user: lingkaran oranye bertepi putih.
class UserDot extends StatelessWidget {
  const UserDot({super.key});

  static const size = 24.0;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
      );
}

/// Lingkaran radius "di sekitarmu" (dalam meter) di atas peta.
///
/// Sengaja tidak memakai CircleLayer bawaan flutter_map: layer itu menggambar
/// lingkaran memakai `drawPoints` berukuran besar yang tidak tampil di
/// renderer web Flutter 3.50. Di sini kita gambar langsung dengan drawCircle.
class NearbyRadiusLayer extends StatelessWidget {
  const NearbyRadiusLayer({
    super.key,
    required this.center,
    required this.radiusMeters,
  });

  final LatLng center;
  final double radiusMeters;

  static const _distance = Distance();

  @override
  Widget build(BuildContext context) {
    // MapCamera.of membuat widget ini ikut di-render ulang saat peta digeser/zoom.
    final camera = MapCamera.of(context);
    final centerPx = camera.getOffsetFromOrigin(center);
    final edgePx = camera
        .getOffsetFromOrigin(_distance.offset(center, radiusMeters, 180));
    final radiusPx = (centerPx - edgePx).distance;

    return MobileLayerTransformer(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _RadiusPainter(centerPx, radiusPx),
        ),
      ),
    );
  }
}

class _RadiusPainter extends CustomPainter {
  _RadiusPainter(this.center, this.radius);

  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()..color = AppColors.peach.withValues(alpha: 0.18),
      )
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.peach.withValues(alpha: 0.8),
      );
  }

  @override
  bool shouldRepaint(_RadiusPainter old) =>
      old.center != center || old.radius != radius;
}
