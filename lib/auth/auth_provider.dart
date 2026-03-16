import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Sits at the top of the widget tree (via ChangeNotifierProvider).
/// Widgets read [appUser] and [role] from here — no direct Firebase calls.
class AuthProvider extends ChangeNotifier {
  final AuthService _service = AuthService();

  AppUser? _appUser;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<UserRole>? _roleSub;

  AuthProvider() {
    _authSub = _service.appUserStream.listen((user) {
      _appUser = user;
      _isLoading = false;
      _errorMessage = null;

      // Subscribe to live role changes so a promotion while logged in
      // is reflected immediately without requiring a re-login.
      _roleSub?.cancel();
      if (user != null) {
        _roleSub = _service.roleStream(user.uid).listen((role) {
          if (_appUser != null && _appUser!.role != role) {
            _appUser = AppUser(
              uid: _appUser!.uid,
              email: _appUser!.email,
              displayName: _appUser!.displayName,
              role: role,
              createdAt: _appUser!.createdAt,
            );
            notifyListeners();
          }
        });
      }

      notifyListeners();
    });
  }

  // ── State ─────────────────────────────────────────────────────────────────

  AppUser?  get appUser     => _appUser;
  bool      get isLoading   => _isLoading;
  bool      get isSignedIn  => _appUser != null;
  UserRole  get role        => _appUser?.role ?? UserRole.user;
  bool      get isModerator => role == UserRole.moderator;
  String?   get errorMessage => _errorMessage;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setLoading();
    final result = await _service.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    return _handleResult(result);
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading();
    final result = await _service.signInWithEmail(
      email: email,
      password: password,
    );
    return _handleResult(result);
  }

  Future<bool> signInWithGoogle() async {
    _setLoading();
    final result = await _service.signInWithGoogle();
    return _handleResult(result);
  }

  Future<bool> sendPasswordReset(String email) async {
    _setLoading();
    final result = await _service.sendPasswordReset(email);
    _isLoading = false;
    if (!result.isSuccess) {
      _errorMessage = result.errorMessage;
    } else {
      _errorMessage = null;
    }
    notifyListeners();
    return result.isSuccess;
  }

  Future<void> signOut() async {
    await _service.signOut();
    _appUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _setLoading() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }

  bool _handleResult(AuthResult result) {
    _isLoading = false;
    if (result.isSuccess) {
      _appUser = result.user;
      _errorMessage = null;
    } else {
      _errorMessage = result.errorMessage;
    }
    notifyListeners();
    return result.isSuccess;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _roleSub?.cancel();
    super.dispose();
  }
}