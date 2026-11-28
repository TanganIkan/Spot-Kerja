import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/place_facts.dart';
import '../models/review.dart';
import '../services/photo_processor.dart';
import '../state/spot_store.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/choice_group.dart';
import '../widgets/photo_picker_row.dart';
import '../widgets/rating_input.dart';

/// Form check-in & review untuk satu spot.
class ReviewFormScreen extends StatefulWidget {
  const ReviewFormScreen({super.key, required this.spotId});

  final String spotId;

  /// Batas wajar hasil speed test yang boleh diisi.
  static const maxSpeedMbps = 2000.0;

  /// Maksimal foto per review (dijaga juga oleh database).
  static const maxPhotos = 3;

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  int _wifi = 0, _power = 0, _quiet = 0, _comfort = 0;
  CrowdLevel _crowd = CrowdLevel.sedang;

  // Atribut lokal (opsional)
  SmokingPolicy? _smoking;
  Seating? _seating;
  bool? _motorParking;
  StayPolicy? _stay;
  Set<BusyTime> _busyTimes = {};
  final _speedController = TextEditingController();
  final _spendController = TextEditingController();
  final _commentController = TextEditingController();
  bool _submitting = false;

  // Foto (sudah diproses: kecil & tanpa EXIF)
  final _picker = ImagePicker();
  final List<Uint8List> _photos = [];
  bool _processingPhotos = false;

  bool get _ratingsComplete =>
      _wifi > 0 && _power > 0 && _quiet > 0 && _comfort > 0;

  @override
  void dispose() {
    _speedController.dispose();
    _spendController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final remaining = ReviewFormScreen.maxPhotos - _photos.length;
    if (remaining <= 0 || _processingPhotos) return;
    final messenger = ScaffoldMessenger.of(context);

    // Di HP: pilih kamera atau galeri. Di web: langsung pilih file.
    var source = ImageSource.gallery;
    if (!kIsWeb) {
      final picked = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Ambil foto'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari galeri'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (picked == null) return;
      source = picked;
    }

    final List<XFile> files;
    try {
      // Diperkecil sedikit oleh picker agar hemat memori; pengecilan akhir &
      // penghapusan EXIF dilakukan oleh PhotoProcessor.
      if (source == ImageSource.camera || remaining == 1) {
        final file = await _picker.pickImage(
          source: source,
          maxWidth: 2400,
          imageQuality: 90,
          requestFullMetadata: false,
        );
        files = [?file];
      } else {
        files = await _picker.pickMultiImage(
          maxWidth: 2400,
          imageQuality: 90,
          limit: remaining,
          requestFullMetadata: false,
        );
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Tidak bisa membuka kamera/galeri. Periksa izin aplikasi.'),
      ));
      return;
    }
    if (files.isEmpty || !mounted) return;

    setState(() => _processingPhotos = true);
    var unreadable = 0;
    for (final file in files.take(remaining)) {
      final processed = await PhotoProcessor.processAsync(await file.readAsBytes());
      if (processed == null) {
        unreadable++;
      } else {
        _photos.add(processed);
      }
    }
    if (!mounted) return;
    setState(() => _processingPhotos = false);
    if (unreadable > 0) {
      messenger.showSnackBar(SnackBar(
        content: Text('$unreadable foto tidak bisa dibaca. Gunakan foto JPG atau PNG.'),
      ));
    }
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final store = context.read<SpotStore>();

    double? speed;
    final rawSpeed = _speedController.text.trim().replaceAll(',', '.');
    if (rawSpeed.isNotEmpty) {
      speed = double.tryParse(rawSpeed);
      if (speed == null ||
          speed <= 0 ||
          speed > ReviewFormScreen.maxSpeedMbps) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Kecepatan WiFi harus angka antara 0 dan 2000 Mbps.'),
        ));
        return;
      }
    }

    int? spend;
    if (_spendController.text.trim().isNotEmpty) {
      spend = parseRupiah(_spendController.text);
      if (spend == null || spend < minSpendRupiah || spend > maxSpendRupiah) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Pengeluaran per orang tidak valid. Contoh: 35000 atau 35rb.'),
        ));
        return;
      }
    }

    setState(() => _submitting = true);
    final result = await store.addReview(
      spotId: widget.spotId,
      wifi: _wifi,
      power: _power,
      quiet: _quiet,
      comfort: _comfort,
      crowd: _crowd,
      wifiSpeedMbps: speed,
      comment: _commentController.text,
      smoking: _smoking,
      seating: _seating,
      motorParking: _motorParking,
      stay: _stay,
      busyTimes: _busyTimes,
      photos: List.of(_photos),
      spendPerPerson: spend,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    final message = switch (result) {
      ReviewResult.savedVerified =>
        'Review tersimpan dengan status check-in terverifikasi. Terima kasih!',
      ReviewResult.savedUnverified =>
        'Review tersimpan. Belum terverifikasi karena kamu tidak terdeteksi '
            'di lokasi.',
      ReviewResult.limitReached =>
        'Kamu sudah mereview tempat ini hari ini.',
      ReviewResult.failed =>
        'Review gagal dikirim. Periksa koneksi internet lalu coba lagi.',
    };
    final failedPhotos = store.lastPhotoFailures;
    messenger.showSnackBar(SnackBar(
      content: Text(failedPhotos > 0 &&
              (result == ReviewResult.savedVerified ||
                  result == ReviewResult.savedUnverified)
          ? '$message ($failedPhotos foto gagal diunggah.)'
          : message),
    ));
    if (result == ReviewResult.savedVerified ||
        result == ReviewResult.savedUnverified) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SpotStore>();
    final spot = store.spotById(widget.spotId);
    final theme = Theme.of(context);
    final limitReached = store.hasReachedReviewLimit(widget.spotId);
    final canSubmit =
        _ratingsComplete && !_submitting && !limitReached && !_processingPhotos;

    return Scaffold(
      appBar: AppBar(title: Text('Review ${spot?.name ?? ''}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (limitReached)
            Card(
              color: theme.colorScheme.errorContainer,
              child: const ListTile(
                leading: Icon(Icons.block),
                title: Text('Batas review tercapai'),
                subtitle: Text(
                  'Kamu sudah mereview tempat ini hari ini. Batasnya 1 review '
                  'per tempat per hari supaya data tetap jujur.',
                ),
              ),
            ),
          Text('Nilai tiap aspek', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          RatingInput(
            label: 'WiFi',
            hint: 'Stabil & cepat?',
            value: _wifi,
            onChanged: (v) => setState(() => _wifi = v),
          ),
          RatingInput(
            label: 'Colokan',
            hint: 'Mudah dapat stopkontak?',
            value: _power,
            onChanged: (v) => setState(() => _power = v),
          ),
          RatingInput(
            label: 'Ketenangan',
            hint: '5 = sangat tenang',
            value: _quiet,
            onChanged: (v) => setState(() => _quiet = v),
          ),
          RatingInput(
            label: 'Kenyamanan',
            hint: 'Kursi & meja untuk kerja lama',
            value: _comfort,
            onChanged: (v) => setState(() => _comfort = v),
          ),
          const SizedBox(height: 16),
          Text('Seberapa ramai sekarang?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<CrowdLevel>(
            segments: [
              for (final c in CrowdLevel.values)
                ButtonSegment(value: c, label: Text(c.label)),
            ],
            selected: {_crowd},
            onSelectionChanged: (s) => setState(() => _crowd = s.first),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _speedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Kecepatan WiFi (Mbps, opsional)',
              helperText: 'Isi dari hasil speed test. Speed test otomatis '
                  'menyusul di versi berikutnya.',
              border: OutlineInputBorder(),
              suffixText: 'Mbps',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _spendController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'Habis berapa per orang? (opsional)',
              helperText: 'Perkiraan makan/minum per orang. Contoh: 35000 atau 35rb',
              border: OutlineInputBorder(),
              prefixText: 'Rp ',
            ),
          ),
          if (store.supportsPhotos) ...[
            const SizedBox(height: 28),
            Text('Foto', style: theme.textTheme.titleMedium),
            Text(
              'Opsional, maksimal ${ReviewFormScreen.maxPhotos} foto. Foto '
              'dikecilkan dan data lokasinya (EXIF) dihapus sebelum diunggah.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            PhotoPickerRow(
              photos: _photos,
              maxPhotos: ReviewFormScreen.maxPhotos,
              busy: _processingPhotos,
              enabled: !_submitting,
              onAdd: _addPhotos,
              onRemove: (i) => setState(() => _photos.removeAt(i)),
            ),
          ],
          const SizedBox(height: 28),
          Text('Info tempat', style: theme.textTheme.titleMedium),
          const Text(
            'Opsional. Isi yang kamu tahu saja, dan tap lagi untuk membatalkan.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          ChoiceGroup<SmokingPolicy>(
            icon: Icons.smoke_free_rounded,
            label: 'Rokok',
            options: SmokingPolicy.values,
            labelOf: (v) => v.label,
            selected: _smoking,
            onChanged: (v) => setState(() => _smoking = v),
          ),
          ChoiceGroup<Seating>(
            icon: Icons.ac_unit_rounded,
            label: 'Tempat duduk',
            options: Seating.values,
            labelOf: (v) => v.label,
            selected: _seating,
            onChanged: (v) => setState(() => _seating = v),
          ),
          ChoiceGroup<bool>(
            icon: Icons.two_wheeler_rounded,
            label: 'Parkir motor mudah?',
            options: const [true, false],
            labelOf: (v) => v ? 'Ya' : 'Tidak',
            selected: _motorParking,
            onChanged: (v) => setState(() => _motorParking = v),
          ),
          ChoiceGroup<StayPolicy>(
            icon: Icons.hourglass_bottom_rounded,
            label: 'Boleh kerja lama?',
            options: StayPolicy.values,
            labelOf: (v) => v.label,
            selected: _stay,
            onChanged: (v) => setState(() => _stay = v),
          ),
          MultiChoiceGroup<BusyTime>(
            icon: Icons.groups_outlined,
            label: 'Biasanya ramai kapan?',
            options: BusyTime.values,
            labelOf: (v) => v.label,
            selected: _busyTimes,
            onChanged: (v) => setState(() => _busyTimes = v),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 280,
            decoration: const InputDecoration(
              labelText: 'Komentar (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_outlined,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review mendapat tanda "check-in terverifikasi" kalau '
                  'lokasimu dalam radius ${SpotStore.checkInRadiusMeters.round()} m '
                  'dari tempat ini.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: canSubmit ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(!_ratingsComplete
                    ? 'Isi keempat rating untuk mengirim'
                    : _photos.isEmpty
                        ? 'Kirim review'
                        : 'Kirim review + ${_photos.length} foto'),
          ),
        ],
      ),
    );
  }
}
