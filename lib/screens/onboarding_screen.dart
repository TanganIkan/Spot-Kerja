import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/local_storage.dart';
import '../state/spot_store.dart';
import '../theme/app_theme.dart';
import '../widgets/spot_photo.dart';
import '../widgets/work_score_badge.dart';
import 'home_screen.dart';

/// Onboarding 3 layar, hanya tampil saat app pertama kali dibuka:
///   1. Apa itu SpotKerja
///   2. Cara membaca Work Score
///   3. Minta izin lokasi (boleh dilewati)
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _finishing = false;

  static const _pages = [
    _PageContent(
      illustration: _WelcomeIllustration(),
      title: 'Kerja di mana saja,\ntanpa tebak-tebakan',
      body: 'Temukan kafe dan co-working yang benar-benar nyaman untuk kerja: '
          'WiFi kencang, colokan cukup, dan suasana tenang.',
    ),
    _PageContent(
      illustration: _ScoreIllustration(),
      title: 'Kenali Work Score',
      body: 'Skor 0–100 dari review sesama pekerja remote. Dihitung dari WiFi, '
          'colokan, ketenangan, dan kenyamanan, dan review terbaru paling '
          'berpengaruh.',
    ),
    _PageContent(
      illustration: _LocationIllustration(),
      title: 'Temukan spot terdekat',
      body: 'Izinkan lokasi supaya kami bisa menampilkan spot di sekitarmu dan '
          'memverifikasi check-in. Lokasimu tidak dibagikan ke siapa pun.',
    ),
  ];

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() => _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );

  Future<void> _finish({required bool allowLocation}) async {
    if (_finishing) return;
    setState(() => _finishing = true);

    final storage = context.read<LocalStorage>();
    final store = context.read<SpotStore>();
    final navigator = Navigator.of(context);

    await storage.setOnboardingDone();
    // Tidak perlu ditunggu: Beranda langsung tampil, lokasi menyusul.
    if (allowLocation) store.refreshLocation();
    if (!mounted) return;
    navigator.pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Tombol "Lewati" (disembunyikan di layar terakhir)
            SizedBox(
              height: 52,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: _isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: _isLast
                        ? null
                        : () => _pageController.animateToPage(
                              _pages.length - 1,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                            ),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted),
                    child: const Text('Lewati'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                    child: Column(
                      children: [
                        // Ilustrasi mengecil otomatis di layar pendek.
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: p.illustration,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _Dots(count: _pages.length, index: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, 24, AppSpacing.page, 8),
              child: FilledButton(
                onPressed: _finishing
                    ? null
                    : _isLast
                        ? () => _finish(allowLocation: true)
                        : _next,
                child: Text(_isLast ? 'Izinkan lokasi' : 'Lanjut'),
              ),
            ),
            SizedBox(
              height: 48,
              child: _isLast
                  ? TextButton(
                      onPressed: _finishing
                          ? null
                          : () => _finish(allowLocation: false),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted),
                      child: const Text('Nanti saja'),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PageContent {
  const _PageContent({
    required this.illustration,
    required this.title,
    required this.body,
  });

  final Widget illustration;
  final String title;
  final String body;
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Halaman ${index + 1} dari $count',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == index ? AppColors.primary : AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      );
}

// ---- Ilustrasi --------------------------------------------------------

/// Layar 1: foto kafe dengan kartu info melayang.
class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 310,
      height: 340,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            right: 24,
            bottom: 36,
            child: SpotPhoto(
              path: 'assets/images/spots/s5.jpg',
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _FloatingCard(
              children: const [
                _FactRow(icon: Icons.wifi_rounded, text: '60 Mbps'),
                SizedBox(height: 8),
                _FactRow(icon: Icons.power_rounded, text: 'Colokan di tiap meja'),
                SizedBox(height: 8),
                _FactRow(icon: Icons.volume_off_outlined, text: 'Cukup tenang'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Layar 2: lencana skor besar + empat aspek penilaian.
class _ScoreIllustration extends StatelessWidget {
  const _ScoreIllustration();

  @override
  Widget build(BuildContext context) {
    Widget aspect(IconData icon, String label, String weight) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primaryText),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text(weight,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        );

    return Container(
      width: 310,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.sand.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WorkScoreBadge(score: 88, hasData: true, size: 104),
          const SizedBox(height: 8),
          const Text('Sangat cocok untuk kerja',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              aspect(Icons.wifi_rounded, 'WiFi', '35%'),
              aspect(Icons.power_rounded, 'Colokan', '25%'),
              aspect(Icons.volume_off_outlined, 'Tenang', '20%'),
              aspect(Icons.chair_outlined, 'Nyaman', '20%'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Layar 3: logo pin di tengah lingkaran radius.
class _LocationIllustration extends StatelessWidget {
  const _LocationIllustration();

  @override
  Widget build(BuildContext context) {
    Widget ring(double size, double alpha) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.peach.withValues(alpha: alpha),
          ),
        );

    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gelombang radius di belakang logo. Lingkaran paling dalam sengaja
          // putih, supaya cincin putus-putus di logo tetap kontras.
          ring(280, 0.12),
          ring(210, 0.18),
          Container(
            width: 150,
            height: 150,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          Image.asset('assets/branding/splash_logo.png', width: 160),
          const Positioned(
            top: 34,
            right: 18,
            child: _MiniPill(text: '88'),
          ),
          const Positioned(
            bottom: 46,
            left: 6,
            child: _MiniPill(text: '80'),
          ),
          const Positioned(
            bottom: 18,
            right: 42,
            child: _MiniPill(text: '63'),
          ),
        ],
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.sand.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.primaryText),
          ),
          const SizedBox(width: 10),
          Text(text,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      );
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 9, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 14, color: AppColors.orange),
            Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      );
}
