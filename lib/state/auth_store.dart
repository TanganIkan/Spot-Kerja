import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Status login user.
abstract class AuthStore extends ChangeNotifier {
  /// false = mode data contoh: semua orang dianggap sudah "login".
  bool get requiresSignIn;
  bool get isSignedIn;
  String? get displayName;
  String? get email;
  String? get avatarUrl;

  Future<void> signInWithGoogle();
  Future<void> signOut();
}

/// Mode data contoh (tanpa Supabase): tidak ada login sungguhan.
class LocalAuthStore extends AuthStore {
  @override
  bool get requiresSignIn => false;
  @override
  bool get isSignedIn => true;
  @override
  String? get displayName => 'Kamu';
  @override
  String? get email => null;
  @override
  String? get avatarUrl => null;

  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signOut() async {}
}

/// Login dengan akun Google lewat Supabase Auth.
class SupabaseAuthStore extends AuthStore {
  SupabaseAuthStore(this._auth) {
    _userId = _auth.currentUser?.id;
    _subscription = _auth.onAuthStateChange.listen((_) {
      // Token di-refresh secara berkala; cukup beri tahu UI saat user berganti.
      final id = _auth.currentUser?.id;
      if (id != _userId) {
        _userId = id;
        notifyListeners();
      }
    });
  }

  final GoTrueClient _auth;
  late final StreamSubscription<AuthState> _subscription;
  String? _userId;

  User? get _user => _auth.currentUser;
  Map<String, dynamic> get _meta => _user?.userMetadata ?? const {};

  @override
  bool get requiresSignIn => true;
  @override
  bool get isSignedIn => _user != null;
  @override
  String? get displayName =>
      _meta['full_name'] as String? ?? _meta['name'] as String? ?? _user?.email;
  @override
  String? get email => _user?.email;
  @override
  String? get avatarUrl => _meta['avatar_url'] as String?;

  @override
  Future<void> signInWithGoogle() async {
    await _auth.signInWithOAuth(
      OAuthProvider.google,
      // Web: kembali ke alamat yang sedang dibuka. Mobile: deep link app.
      redirectTo: kIsWeb ? Uri.base.origin : AppConfig.authRedirectMobile,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
