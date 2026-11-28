import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'config/app_config.dart';
import 'data/dummy_spot_repository.dart';
import 'data/local_storage.dart';
import 'data/spot_repository.dart';
import 'data/supabase_spot_repository.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/auth_store.dart';
import 'state/favorites_store.dart';
import 'state/spot_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);
  final showOnboarding = !storage.onboardingDone;

  // Pilih sumber data: Supabase kalau kuncinya ada (env.json), data contoh
  // kalau tidak. Layar-layar tidak perlu tahu bedanya.
  final SpotRepository repository;
  final AuthStore auth;
  LatLng? defaultCenter;
  String? defaultAreaName;

  if (AppConfig.useSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
    );
    final client = Supabase.instance.client;
    repository = SupabaseSpotRepository(client);
    auth = SupabaseAuthStore(client.auth);
    defaultCenter = AppConfig.baliCenter;
    defaultAreaName = AppConfig.baliAreaName;
  } else {
    repository = DummySpotRepository(storage);
    auth = LocalAuthStore();
  }

  final spotStore = SpotStore(
    repository,
    defaultCenter: defaultCenter,
    defaultAreaName: defaultAreaName ?? 'Jakarta Selatan (area contoh)',
  )
    // Izin lokasi baru diminta setelah onboarding (layar ke-3).
    ..load(locate: !showOnboarding);

  // Login/logout mengubah status "review milikku" -> muat ulang review.
  auth.addListener(spotStore.reloadReviews);

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalStorage>.value(value: storage),
        ChangeNotifierProvider<AuthStore>.value(value: auth),
        ChangeNotifierProvider.value(value: spotStore),
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
