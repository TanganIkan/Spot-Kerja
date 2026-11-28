import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spot_kerja/data/dummy_spot_repository.dart';
import 'package:spot_kerja/data/local_storage.dart';
import 'package:spot_kerja/main.dart';
import 'package:spot_kerja/screens/home_screen.dart';
import 'package:spot_kerja/screens/review_form_screen.dart';
import 'package:spot_kerja/services/location_service.dart';
import 'package:spot_kerja/state/auth_store.dart';
import 'package:spot_kerja/state/favorites_store.dart';
import 'package:spot_kerja/state/spot_store.dart';

/// Uji alur utama: daftar → filter → detail → review → favorit.
void main() {
  testWidgets('alur utama aplikasi', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthStore>.value(value: LocalAuthStore()),
          ChangeNotifierProvider(
            create: (_) => SpotStore(DummySpotRepository(storage))..load(),
          ),
          ChangeNotifierProvider(create: (_) => FavoritesStore(storage)),
        ],
        child: const SpotKerjaApp(),
      ),
    );
    // Tunggu data dimuat + pencarian lokasi habis waktu (tidak ada GPS di test).
    await tester.pump(LocationService.timeout + const Duration(seconds: 1));
    await tester.pump();

    BuildContext ctx() =>
        tester.element(find.byType(HomeScreen, skipOffstage: false));

    // Tidak pakai pumpAndSettle: peta di tab lain terus mencoba memuat tile
    // (test tidak punya internet), jadi animasinya tidak pernah 'selesai'.
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // 1. Beranda tampil, Kedai Fokus (spot terdekat) ada di carousel
    expect(find.text('Temukan spot kerja'), findsOneWidget);
    expect(find.text('Kedai Fokus'), findsWidgets);

    // 2. "Lihat semua" → filter "WiFi cepat" menyembunyikan spot 12 Mbps
    await tester.tap(find.text('Lihat semua').first);
    await settle();
    expect(find.text('Semua spot'), findsOneWidget);
    // (font di test lebih lebar, jadi chip perlu di-scroll ke layar dulu)
    final wifiChip = find.text('WiFi cepat');
    await tester.ensureVisible(wifiChip);
    await settle();
    await tester.tap(wifiChip);
    await tester.pump();
    expect(find.text('Kedai Fokus'), findsNothing);
    await tester.tap(wifiChip);
    await tester.pump();

    // 3. Buka detail
    await tester.tap(find.text('Kedai Fokus'));
    await settle();
    expect(find.text('Kondisi untuk kerja'), findsOneWidget);
    final scoreBefore = ctx().read<SpotStore>().statsFor('s3').workScore;

    // 4. Simpan (bookmark) dari halaman detail
    await tester.tap(find.byTooltip('Simpan'));
    await tester.pump();
    expect(ctx().read<FavoritesStore>().isFavorite('s3'), isTrue);

    // 5. Isi & kirim review
    await tester.tap(find.text('Check-in & Review'));
    await settle();
    for (final label in ['WiFi', 'Colokan', 'Ketenangan', 'Kenyamanan']) {
      final star = find.byTooltip('$label 5');
      await tester.ensureVisible(star);
      await tester.tap(star);
      await tester.pump();
    }
    // Form cukup panjang: scroll sampai tombol kirim ter-render.
    final submit = find.text('Kirim review');
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ReviewFormScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(submit);
    await tester.pump(LocationService.timeout + const Duration(seconds: 1));
    await settle();

    final store = ctx().read<SpotStore>();
    final mine = store.reviewsFor('s3').first;
    expect(mine.author, 'Kamu');
    expect(mine.verifiedCheckIn, isFalse); // tidak ada GPS di test
    expect(store.statsFor('s3').workScore, greaterThan(scoreBefore));
    expect(storage.loadUserReviews(), hasLength(1)); // tersimpan di perangkat

    // 6. Batas 1 review per hari
    expect(store.hasReachedReviewLimit('s3'), isTrue);

    // Habiskan timer snackbar
    await tester.pump(const Duration(seconds: 5));
    await settle();
  });
}
