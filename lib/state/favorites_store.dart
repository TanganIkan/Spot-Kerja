import 'package:flutter/foundation.dart';

import '../data/local_storage.dart';

/// Daftar spot favorit, disimpan di perangkat.
class FavoritesStore extends ChangeNotifier {
  FavoritesStore(LocalStorage storage)
      : _storage = storage,
        _ids = storage.loadFavorites();

  final LocalStorage _storage;
  final Set<String> _ids;

  Set<String> get ids => Set.unmodifiable(_ids);

  bool isFavorite(String spotId) => _ids.contains(spotId);

  void toggle(String spotId) {
    if (!_ids.remove(spotId)) _ids.add(spotId);
    _storage.saveFavorites(_ids);
    notifyListeners();
  }
}
