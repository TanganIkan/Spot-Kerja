import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Deretan foto yang dipilih user + tombol "Tambah foto".
class PhotoPickerRow extends StatelessWidget {
  const PhotoPickerRow({
    super.key,
    required this.photos,
    required this.maxPhotos,
    required this.onAdd,
    required this.onRemove,
    this.busy = false,
    this.enabled = true,
  });

  final List<Uint8List> photos;
  final int maxPhotos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  /// Sedang memproses foto (mengecilkan & menghapus EXIF).
  final bool busy;
  final bool enabled;

  static const _size = 88.0;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < photos.length; i++)
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                child: Image.memory(
                  photos[i],
                  width: _size,
                  height: _size,
                  fit: BoxFit.cover,
                  semanticLabel: 'Foto ${i + 1}',
                ),
              ),
              if (enabled)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Material(
                    color: AppColors.ink,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onRemove(i),
                      child: const Tooltip(
                        message: 'Hapus foto',
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (photos.length < maxPhotos)
          Material(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              onTap: enabled && !busy ? onAdd : null,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(color: AppColors.line),
                ),
                child: busy
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_outlined,
                              color: AppColors.primaryText),
                          const SizedBox(height: 4),
                          Text(
                            '${photos.length}/$maxPhotos',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
