import 'package:material_ui/material_ui.dart';

/// Palet warna SpotKerja.
///
/// Aturan pemakaian: latar tetap putih, warna oranye hanya untuk hal yang
/// penting (tombol utama, chip aktif, ikon aktif) supaya tetap menonjol.
class AppColors {
  // Palet utama
  static const primary = Color(0xFFEE6200); // tombol utama, chip aktif
  static const orange = Color(0xFFFF9A00); // aksen: ikon skor, highlight
  static const peach = Color(0xFFFBA17E); // tint lembut: radius peta, track bar
  static const sand = Color(0xFFF7D794); // badge & latar highlight

  /// Oranye lebih gelap untuk teks kecil di atas putih (kontras lebih baik).
  static const primaryText = Color(0xFFB84C00);

  // Netral
  static const ink = Color(0xFF1C1B22); // teks utama
  static const muted = Color(0xFF8B8A96); // teks sekunder
  static const line = Color(0xFFEDEDF1); // garis & border
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF7F7F9); // latar field & kartu sekunder

  // Status
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFD32F2F);
}

/// Ukuran jarak & sudut yang dipakai berulang, supaya konsisten.
class AppSpacing {
  static const page = 20.0; // padding kiri-kanan layar
  static const radius = 16.0; // sudut kartu
  static const radiusSmall = 12.0; // sudut thumbnail & field
}

class AppTheme {
  /// Font utama (geometris, dari assets/fonts).
  static const fontFamily = 'PlusJakartaSans';

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.orange,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outlineVariant: AppColors.line,
      error: AppColors.danger,
    );

    const textTheme = TextTheme(
      headlineMedium: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 15, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45),
      bodySmall: TextStyle(fontSize: 12.5, height: 1.35),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: base.textTheme.merge(textTheme).apply(
            bodyColor: AppColors.ink,
            displayColor: AppColors.ink,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.line,
          minimumSize: const Size.fromHeight(54),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSoft,
        hintStyle: const TextStyle(color: AppColors.muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.line),
        labelStyle: const TextStyle(
            color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.ink,
          ),
          side: const WidgetStatePropertyAll(
              BorderSide(color: AppColors.line)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: Color(0xFFFDE3D6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
    );
  }

  /// Bayangan lembut untuk kartu & elemen melayang di atas peta.
  static List<BoxShadow> get softShadow => const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];
}
