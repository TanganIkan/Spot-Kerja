import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spot_kerja/data/dummy_spot_repository.dart';
import 'package:spot_kerja/data/local_storage.dart';
import 'package:spot_kerja/main.dart';
import 'package:spot_kerja/state/favorites_store.dart';
import 'package:spot_kerja/state/spot_store.dart';

void main() {
  testWidgets('onboarding: 3 layar, "Nanti saja" → Beranda, tidak muncul lagi',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorage(await SharedPreferences.getInstance());
    expect(storage.onboardingDone, isFalse);

    final store = SpotStore(DummySpotRepository(storage));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LocalStorage>.value(value: storage),
          ChangeNotifierProvider.value(value: store..load(locate: false)),
          ChangeNotifierProvider(create: (_) => FavoritesStore(storage)),
        ],
        child: const SpotKerjaApp(showOnboarding: true),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // Layar 1 → 2 → 3
    expect(find.text('Lanjut'), findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await settle();
    expect(find.text('Kenali Work Score'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await settle();

    // Layar terakhir: tombol izin lokasi + "Nanti saja"
    expect(find.text('Izinkan lokasi'), findsOneWidget);
    expect(find.text('Nanti saja'), findsOneWidget);
    // Izin lokasi belum pernah diminta selama onboarding
    expect(store.isLocating, isFalse);
    expect(store.hasRealLocation, isFalse);

    await tester.tap(find.text('Nanti saja'));
    await settle();

    expect(find.text('Temukan spot kerja'), findsOneWidget);
    expect(storage.onboardingDone, isTrue);
    expect(store.isLocating, isFalse); // "Nanti saja" = tidak minta lokasi
  });
}
