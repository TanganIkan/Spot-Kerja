import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Pertanyaan pilihan tunggal yang boleh dikosongkan:
/// tap pilihan yang sedang aktif sekali lagi untuk membatalkannya.
class ChoiceGroup<T> extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.icon,
    required this.label,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final List<T> options;
  final String Function(T) labelOf;
  final T? selected;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Question(
      icon: icon,
      label: label,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            _OptionChip(
              label: labelOf(option),
              selected: option == selected,
              onTap: () => onChanged(option == selected ? null : option),
            ),
        ],
      ),
    );
  }
}

/// Pertanyaan pilihan ganda (misalnya jam ramai).
class MultiChoiceGroup<T> extends StatelessWidget {
  const MultiChoiceGroup({
    super.key,
    required this.icon,
    required this.label,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final List<T> options;
  final String Function(T) labelOf;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Question(
      icon: icon,
      label: label,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            _OptionChip(
              label: labelOf(option),
              selected: selected.contains(option),
              onTap: () => onChanged(
                selected.contains(option)
                    ? ({...selected}..remove(option))
                    : {...selected, option},
              ),
            ),
        ],
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryText),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.line),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      );
}
