import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/dummy_spot_repository.dart';
import 'data/local_storage.dart';
import 'screens/home_screen.dart';
import 'state/favorites_store.dart';
import 'state/spot_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);

  // Ganti DummySpotRepository dengan SupabaseSpotRepository di tahap berikutnya.
  final repository = DummySpotRepository(storage);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpotStore(repository)..load()),
        ChangeNotifierProvider(create: (_) => FavoritesStore(storage)),
      ],
      child: const SpotKerjaApp(),
    ),
  );
}

class SpotKerjaApp extends StatelessWidget {
  const SpotKerjaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpotKerja',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
