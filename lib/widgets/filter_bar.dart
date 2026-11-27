import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/spot_filter.dart';
import '../state/spot_store.dart';
import '../theme/app_theme.dart';

/// Chip filter. [wrap] = true untuk tampilan bertumpuk (di dalam sheet),
/// false untuk satu baris yang bisa digeser.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, this.wrap = false});

  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SpotStore>();
    final f = store.filter;

    Widget chip(
      String label,
      IconData icon,
      bool selected,
      SpotFilter Function(bool value) apply,
    ) {
      final fg = selected ? Colors.white : AppColors.ink;
      return FilterChip(
        avatar: Icon(icon, size: 17, color: fg),
        label: Text(label),
        labelStyle: TextStyle(
          color: fg,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        side: BorderSide(
            color: selected ? AppColors.primary : AppColors.line),
        onSelected: (v) => store.setFilter(apply(v)),
      );
    }

    final chips = [
      chip('WiFi cepat', Icons.wifi_rounded, f.fastWifi,
          (v) => f.copyWith(fastWifi: v)),
      chip('Banyak colokan', Icons.power_rounded, f.manyOutlets,
          (v) => f.copyWith(manyOutlets: v)),
      chip('Tenang', Icons.volume_off_outlined, f.quiet,
          (v) => f.copyWith(quiet: v)),
      chip('Buka sekarang', Icons.storefront_outlined, f.openNow,
          (v) => f.copyWith(openNow: v)),
      chip('Buka malam', Icons.nightlight_outlined, f.openLate,
          (v) => f.copyWith(openLate: v)),
      // Atribut lokal
      chip('Bebas rokok', Icons.smoke_free_rounded, f.smokeFree,
          (v) => f.copyWith(smokeFree: v)),
      chip('Ber-AC', Icons.ac_unit_rounded, f.airConditioned,
          (v) => f.copyWith(airConditioned: v)),
      chip('Parkir motor', Icons.two_wheeler_rounded, f.motorParking,
          (v) => f.copyWith(motorParking: v)),
      chip('Boleh duduk lama', Icons.hourglass_bottom_rounded, f.longStay,
          (v) => f.copyWith(longStay: v)),
    ];

    if (wrap) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page, vertical: 6),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

/// Pilihan urutan: Terdekat / Work Score tertinggi.
class SortSelector extends StatelessWidget {
  const SortSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SpotStore>();
    return SegmentedButton<SortBy>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: SortBy.distance,
          icon: Icon(Icons.near_me_outlined, size: 18),
          label: Text('Terdekat'),
        ),
        ButtonSegment(
          value: SortBy.workScore,
          icon: Icon(Icons.bolt_rounded, size: 18),
          label: Text('Work Score'),
        ),
      ],
      selected: {store.filter.sortBy},
      onSelectionChanged: (s) =>
          store.setFilter(store.filter.copyWith(sortBy: s.first)),
    );
  }
}

/// Bottom sheet berisi semua filter. Filter langsung diterapkan saat dipilih.
Future<void> showFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final store = sheetContext.watch<SpotStore>();
      final count = store.visibleSpots.length;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Filter',
                      style: Theme.of(sheetContext).textTheme.titleLarge),
                  const Spacer(),
                  if (store.filter.isActive)
                    TextButton(
                      onPressed: () =>
                          store.setFilter(store.filter.cleared()),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryText),
                      child: const Text('Reset'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Urutkan',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const SortSelector(),
              const SizedBox(height: 20),
              const Text('Fasilitas, aturan & jam buka',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const FilterBar(wrap: true),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text('Tampilkan $count tempat'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
