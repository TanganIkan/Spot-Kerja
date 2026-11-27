import 'place_facts.dart';

/// Tingkat keramaian yang dilaporkan user saat check-in.
enum CrowdLevel { sepi, sedang, ramai }

extension CrowdLevelLabel on CrowdLevel {
  String get label => switch (this) {
        CrowdLevel.sepi => 'Sepi',
        CrowdLevel.sedang => 'Sedang',
        CrowdLevel.ramai => 'Ramai',
      };
}

/// Satu review / check-in dari user untuk sebuah spot.
///
/// Setiap aspek dinilai 1–5. Nilai-nilai ini yang nanti diolah
/// menjadi Work Score di [SpotStats].
class Review {
  const Review({
    required this.id,
    required this.spotId,
    required this.author,
    required this.wifi,
    required this.power,
    required this.quiet,
    required this.comfort,
    required this.crowd,
    required this.createdAt,
    this.comment = '',
    this.wifiSpeedMbps,
    this.verifiedCheckIn = false,
    this.isMine = false,
    this.smoking,
    this.seating,
    this.motorParking,
    this.stay,
    this.busyTimes = const {},
  });

  final String id;
  final String spotId;
  final String author;

  /// Kualitas WiFi (1–5).
  final int wifi;

  /// Ketersediaan colokan (1–5).
  final int power;

  /// Ketenangan, 5 = sangat tenang (1–5).
  final int quiet;

  /// Kenyamanan kursi & meja (1–5).
  final int comfort;

  final CrowdLevel crowd;
  final String comment;
  final DateTime createdAt;

  /// Hasil speed test (opsional).
  final double? wifiSpeedMbps;

  /// True kalau saat submit, user berada dalam radius check-in dari spot.
  final bool verifiedCheckIn;

  /// True kalau review ini dibuat oleh user di perangkat ini.
  final bool isMine;

  // ---- Atribut lokal (opsional, null = tidak diisi) ----
  final SmokingPolicy? smoking;
  final Seating? seating;
  final bool? motorParking;
  final StayPolicy? stay;
  final Set<BusyTime> busyTimes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'spotId': spotId,
        'author': author,
        'wifi': wifi,
        'power': power,
        'quiet': quiet,
        'comfort': comfort,
        'crowd': crowd.name,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
        'wifiSpeedMbps': wifiSpeedMbps,
        'verifiedCheckIn': verifiedCheckIn,
        'isMine': isMine,
        'smoking': smoking?.name,
        'seating': seating?.name,
        'motorParking': motorParking,
        'stay': stay?.name,
        'busyTimes': busyTimes.map((t) => t.name).toList(),
      };

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        spotId: json['spotId'] as String,
        author: json['author'] as String,
        wifi: json['wifi'] as int,
        power: json['power'] as int,
        quiet: json['quiet'] as int,
        comfort: json['comfort'] as int,
        crowd: CrowdLevel.values.byName(json['crowd'] as String),
        comment: json['comment'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        wifiSpeedMbps: (json['wifiSpeedMbps'] as num?)?.toDouble(),
        verifiedCheckIn: json['verifiedCheckIn'] as bool? ?? false,
        isMine: json['isMine'] as bool? ?? false,
        // Field di bawah tidak ada di review versi lama -> null / kosong.
        smoking: _enumOrNull(SmokingPolicy.values, json['smoking']),
        seating: _enumOrNull(Seating.values, json['seating']),
        motorParking: json['motorParking'] as bool?,
        stay: _enumOrNull(StayPolicy.values, json['stay']),
        busyTimes: {
          for (final name in (json['busyTimes'] as List<dynamic>? ?? const []))
            ?_enumOrNull(BusyTime.values, name),
        },
      );

  static T? _enumOrNull<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
