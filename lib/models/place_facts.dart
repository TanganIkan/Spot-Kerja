import 'package:material_ui/material_ui.dart';

/// Atribut lokal sebuah tempat: hal-hal yang penting untuk pekerja di
/// Indonesia tapi jarang ada di app global.
///
/// Diisi user lewat form review (semuanya opsional), lalu digabung dengan
/// suara terbanyak di [PlaceFacts.fromAnswers].

enum SmokingPolicy { smokeFree, separateArea, allowed }

extension SmokingPolicyLabel on SmokingPolicy {
  String get label => switch (this) {
        SmokingPolicy.smokeFree => 'Bebas rokok',
        SmokingPolicy.separateArea => 'Area rokok terpisah',
        SmokingPolicy.allowed => 'Boleh merokok',
      };
}

enum Seating { indoorAc, outdoor, both }

extension SeatingLabel on Seating {
  String get label => switch (this) {
        Seating.indoorAc => 'Indoor ber-AC',
        Seating.outdoor => 'Outdoor',
        Seating.both => 'Indoor & outdoor',
      };
}

enum StayPolicy { unlimited, minimumOrder, timeLimited }

extension StayPolicyLabel on StayPolicy {
  String get label => switch (this) {
        StayPolicy.unlimited => 'Bebas duduk lama',
        StayPolicy.minimumOrder => 'Ada minimum order',
        StayPolicy.timeLimited => 'Dibatasi waktu',
      };
}

enum BusyTime { pagi, siang, sore, malam }

extension BusyTimeLabel on BusyTime {
  String get label => switch (this) {
        BusyTime.pagi => 'Pagi',
        BusyTime.siang => 'Siang',
        BusyTime.sore => 'Sore',
        BusyTime.malam => 'Malam',
      };

  IconData get icon => switch (this) {
        BusyTime.pagi => Icons.wb_twilight_rounded,
        BusyTime.siang => Icons.wb_sunny_outlined,
        BusyTime.sore => Icons.wb_twilight_outlined,
        BusyTime.malam => Icons.nightlight_outlined,
      };
}

/// Jawaban atribut lokal dari satu review, plus bobotnya (dari kebaruan).
class FactAnswer {
  const FactAnswer({
    required this.weight,
    required this.createdAt,
    this.smoking,
    this.seating,
    this.motorParking,
    this.stay,
    this.busyTimes = const {},
  });

  final double weight;
  final DateTime createdAt;
  final SmokingPolicy? smoking;
  final Seating? seating;
  final bool? motorParking;
  final StayPolicy? stay;
  final Set<BusyTime> busyTimes;
}

/// Hasil gabungan atribut lokal sebuah spot. `null` = belum ada info.
class PlaceFacts {
  const PlaceFacts({
    this.smoking,
    this.seating,
    this.motorParking,
    this.stay,
    this.busyTimes = const {},
    this.reportCount = 0,
  });

  static const empty = PlaceFacts();

  /// Jam ramai ikut ditampilkan kalau dilaporkan oleh minimal separuh
  /// (berbobot) dari yang menjawab pertanyaan jam ramai.
  static const busyTimeMinShare = 0.5;

  final SmokingPolicy? smoking;
  final Seating? seating;
  final bool? motorParking;
  final StayPolicy? stay;
  final Set<BusyTime> busyTimes;

  /// Jumlah review yang mengisi minimal satu atribut lokal.
  final int reportCount;

  bool get hasData => reportCount > 0;

  /// Ada ruangan tanpa asap rokok (seluruhnya bebas rokok, atau area
  /// merokoknya terpisah).
  bool get hasSmokeFreeRoom =>
      smoking == SmokingPolicy.smokeFree ||
      smoking == SmokingPolicy.separateArea;

  bool get hasAc => seating == Seating.indoorAc || seating == Seating.both;

  bool get allowsLongStay => stay == StayPolicy.unlimited;

  factory PlaceFacts.fromAnswers(List<FactAnswer> answers) {
    final reports = answers.where((a) =>
        a.smoking != null ||
        a.seating != null ||
        a.motorParking != null ||
        a.stay != null ||
        a.busyTimes.isNotEmpty);
    if (reports.isEmpty) return empty;

    final busyAnswers = answers.where((a) => a.busyTimes.isNotEmpty).toList();
    final busyTotal = busyAnswers.fold<double>(0, (sum, a) => sum + a.weight);
    final busyTimes = <BusyTime>{
      for (final t in BusyTime.values)
        if (busyTotal > 0 &&
            busyAnswers
                        .where((a) => a.busyTimes.contains(t))
                        .fold<double>(0, (sum, a) => sum + a.weight) /
                    busyTotal >=
                busyTimeMinShare)
          t,
    };

    return PlaceFacts(
      smoking: _majority(answers, (a) => a.smoking),
      seating: _majority(answers, (a) => a.seating),
      motorParking: _majority(answers, (a) => a.motorParking),
      stay: _majority(answers, (a) => a.stay),
      busyTimes: busyTimes,
      reportCount: reports.length,
    );
  }

  /// Suara terbanyak (berbobot). Kalau seri, menang jawaban yang paling baru.
  static T? _majority<T extends Object>(
    List<FactAnswer> answers,
    T? Function(FactAnswer) pick,
  ) {
    final score = <T, double>{};
    final latest = <T, DateTime>{};
    for (final a in answers) {
      final value = pick(a);
      if (value == null) continue;
      score[value] = (score[value] ?? 0) + a.weight;
      final prev = latest[value];
      if (prev == null || a.createdAt.isAfter(prev)) {
        latest[value] = a.createdAt;
      }
    }
    if (score.isEmpty) return null;
    final ranked = score.keys.toList()
      ..sort((x, y) {
        final byScore = score[y]!.compareTo(score[x]!);
        return byScore != 0 ? byScore : latest[y]!.compareTo(latest[x]!);
      });
    return ranked.first;
  }
}
