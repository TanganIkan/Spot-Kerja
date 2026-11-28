import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Foto spot dari assets atau URL. Kalau foto tidak ada / gagal dimuat,
/// tampilkan placeholder supaya layout tidak rusak.
class SpotPhoto extends StatelessWidget {
  const SpotPhoto({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
  });

  final String? path;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.sand.withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: const Icon(Icons.local_cafe_outlined,
          color: AppColors.primaryText, size: 32),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: switch (path) {
          null => placeholder,
          // Foto dari internet (misalnya Supabase Storage)
          final url when url.startsWith('http') => Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : placeholder,
            ),
          // Foto bawaan app (assets/)
          final asset => Image.asset(
              asset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
        },
      ),
    );
  }
}
