import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Sits at the top of the widget tree (via ChangeNotifierProvider).
/// Widgets read [appUser], [role], and [accountStatus] from here.
class AuthProvider extends ChangeNotifier {
  final AuthService _service = AuthService();

  AppUser?       _appUser;
  bool           _isLoading     = true;
  String?        _errorMessage;
  AccountStatus  _accountStatus = AccountStatus.active;

  StreamSubscription<AppUser?>?       _authSub;
  StreamSubscription<UserRole>?       _roleSub;
  StreamSubscription<AccountStatus>?  _statusSub;

  AuthProvider() {
    _authSub = _service.appUserStream.listen((user) {
      _appUser       = user;
      _isLoading     = false;
      _errorMessage  = null;
      _accountStatus = user?.status ?? AccountStatus.active;

      _roleSub?.cancel();
      _statusSub?.cancel();

      if (user != null) {
        // Live role changes — e.g. moderator promotion without re-login
        _roleSub = _service.roleStream(user.uid).listen((role) {
          if (_appUser != null && _appUser!.role != role) {
            _appUser = AppUser(
              uid:              _appUser!.uid,
              email:            _appUser!.email,
              displayName:      _appUser!.displayName,
              role:             role,
              status:           _appUser!.status,
              shadowBanned:     _appUser!.shadowBanned,
              createdAt:        _appUser!.createdAt,
              restrictionEndsAt: _appUser!.restrictionEndsAt,
            );
            notifyListeners();
          }
        });

        // Live status changes — ban/suspend applied while user is logged in
        // takes effect immediately without requiring a re-login.
        _statusSub = _service.statusStream(user.uid).listen((status) {
          _accountStatus = status;

          // Force sign-out if banned or suspended mid-session
          if (!status.canSignIn) {
            _service.signOut();
            // _appUser is cleared by the authStateChanges stream above
          }

          notifyListeners();
        });
      }

      notifyListeners();
    });
  }

  // ── State ─────────────────────────────────────────────────────────────────

  AppUser?      get appUser       => _appUser;
  bool          get isLoading     => _isLoading;
  bool          get isSignedIn    => _appUser != null;
  UserRole      get role          => _appUser?.role ?? UserRole.user;
  bool          get isModerator   => role == UserRole.moderator;
  String?       get errorMessage  => _errorMessage;
  AccountStatus get accountStatus => _accountStatus;
  bool          get isBanned      => _accountStatus == AccountStatus.banned;
  bool          get isSuspended   => _accountStatus == AccountStatus.suspended;
  bool          get isShadowBanned => _accountStatus == AccountStatus.shadowBanned;
  /// Whether the signed-in user is allowed to create posts/comments.
  bool          get canPost       => _accountStatus.canPost;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setLoading();
    final result = await _service.signUpWithEmail(
      email:       email,
      password:    password,
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
      email:    email,
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
    _appUser       = null;
    _errorMessage  = null;
    _accountStatus = AccountStatus.active;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _setLoading() {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
  }

  bool _handleResult(AuthResult result) {
    _isLoading = false;
    if (result.isSuccess) {
      _appUser       = result.user;
      _accountStatus = result.user?.status ?? AccountStatus.active;
      _errorMessage  = null;
    } else if (result.isRestricted) {
      // Surface the restriction message like a normal auth error so the
      // login page can display it without any extra changes.
      _errorMessage = result.restriction!.userMessage;
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
    _statusSub?.cancel();
    super.dispose();
  }
}