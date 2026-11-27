import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Tombol ikon bulat putih dengan bayangan lembut
/// (tombol kembali / simpan di atas foto, tombol lokasi, tombol filter).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.ink,
    this.size = 44,
    this.showDot = false,
    this.bordered = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  final double size;

  /// Titik oranye kecil di pojok, misalnya untuk "filter sedang aktif".
  final bool showDot;

  /// Pakai garis tepi alih-alih bayangan (untuk di atas latar putih).
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: CircleBorder(
          side: bordered
              ? const BorderSide(color: AppColors.line)
              : BorderSide.none,
        ),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: bordered ? null : AppTheme.softShadow,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: color, size: size * 0.48),
                if (showDot)
                  Positioned(
                    top: size * 0.22,
                    right: size * 0.22,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
