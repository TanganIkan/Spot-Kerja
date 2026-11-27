import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/dummy_spot_repository.dart';
import 'data/local_storage.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/favorites_store.dart';
import 'state/spot_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);
  final showOnboarding = !storage.onboardingDone;

  // Ganti DummySpotRepository dengan SupabaseSpotRepository di tahap berikutnya.
  final repository = DummySpotRepository(storage);

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalStorage>.value(value: storage),
        // Izin lokasi baru diminta setelah onboarding (layar ke-3).
        ChangeNotifierProvider(
          create: (_) => SpotStore(repository)..load(locate: !showOnboarding),
        ),
        ChangeNotifierProvider(create: (_) => FavoritesStore(storage)),
      ],
      child: SpotKerjaApp(showOnboarding: showOnboarding),
    ),
  );
}

class SpotKerjaApp extends StatelessWidget {
  const SpotKerjaApp({super.key, this.showOnboarding = false});

  final bool showOnboarding;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpotKerja',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
