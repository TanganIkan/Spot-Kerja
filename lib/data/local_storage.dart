import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/review.dart';

/// Penyimpanan di perangkat (favorit & review milik user).
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _favoritesKey = 'favorites';
  static const _reviewsKey = 'user_reviews';
  static const _onboardingKey = 'onboarding_done';

  /// True kalau user sudah pernah menyelesaikan onboarding.
  bool get onboardingDone => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingDone() => _prefs.setBool(_onboardingKey, true);

  Set<String> loadFavorites() =>
      (_prefs.getStringList(_favoritesKey) ?? const []).toSet();

  Future<void> saveFavorites(Set<String> ids) =>
      _prefs.setStringList(_favoritesKey, ids.toList());

  List<Review> loadUserReviews() {
    final raw = _prefs.getString(_reviewsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveUserReviews(List<Review> reviews) => _prefs.setString(
        _reviewsKey,
        jsonEncode(reviews.map((r) => r.toJson()).toList()),
      );
}
