import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/place_facts.dart';
import '../models/review.dart';
import '../state/spot_store.dart';
import '../theme/app_theme.dart';
import '../widgets/choice_group.dart';
import '../widgets/rating_input.dart';

/// Form check-in & review untuk satu spot.
class ReviewFormScreen extends StatefulWidget {
  const ReviewFormScreen({super.key, required this.spotId});

  final String spotId;

  /// Batas wajar hasil speed test yang boleh diisi.
  static const maxSpeedMbps = 2000.0;

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
  final _commentController = TextEditingController();
  bool _submitting = false;

  bool get _ratingsComplete =>
      _wifi > 0 && _power > 0 && _quiet > 0 && _comfort > 0;

  @override
  void dispose() {
    _speedController.dispose();
    _commentController.dispose();
    super.dispose();
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
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
    if (result != ReviewResult.limitReached) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SpotStore>();
    final spot = store.spotById(widget.spotId);
    final theme = Theme.of(context);
    final limitReached = store.hasReachedReviewLimit(widget.spotId);
    final canSubmit = _ratingsComplete && !_submitting && !limitReached;

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
                : Text(_ratingsComplete
                    ? 'Kirim review'
                    : 'Isi keempat rating untuk mengirim'),
          ),
        ],
      ),
    );
  }
}
