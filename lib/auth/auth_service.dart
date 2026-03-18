import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ── User roles ────────────────────────────────────────────────────────────────

enum UserRole { user, moderator }

extension UserRoleExtension on UserRole {
  String get name => this == UserRole.moderator ? 'moderator' : 'user';

  static UserRole fromString(String? s) =>
      s == 'moderator' ? UserRole.moderator : UserRole.user;
}

// ── Account status ────────────────────────────────────────────────────────────

enum AccountStatus { active, warned, suspended, shadowBanned, banned }

extension AccountStatusExtension on AccountStatus {
  static AccountStatus fromString(String? s) {
    switch (s) {
      case 'warned':       return AccountStatus.warned;
      case 'suspended':    return AccountStatus.suspended;
      case 'shadow_banned':
      case 'shadowBanned': return AccountStatus.shadowBanned;
      case 'banned':       return AccountStatus.banned;
      default:             return AccountStatus.active;
    }
  }

  bool get canSignIn =>
      this != AccountStatus.banned && this != AccountStatus.suspended;

  bool get canPost =>
      this != AccountStatus.banned &&
      this != AccountStatus.suspended &&
      this != AccountStatus.shadowBanned;
}

// ── Typed exception thrown when a restricted user tries to sign in ─────────────

class AccountRestrictedException implements Exception {
  final AccountStatus status;
  final DateTime?     restrictionEndsAt;
  const AccountRestrictedException(this.status, {this.restrictionEndsAt});

  String get userMessage {
    switch (status) {
      case AccountStatus.banned:
        return 'Your account has been permanently banned.';
      case AccountStatus.suspended:
        final end = restrictionEndsAt;
        if (end != null && end.isAfter(DateTime.now())) {
          final d = end.difference(DateTime.now());
          final String timeLabel;
          if (d.inDays >= 1) {
            timeLabel = '${d.inDays} day${d.inDays == 1 ? '' : 's'}';
          } else if (d.inHours >= 1) {
            timeLabel = '${d.inHours} hour${d.inHours == 1 ? '' : 's'}';
          } else if (d.inMinutes >= 1) {
            timeLabel = '${d.inMinutes} minute${d.inMinutes == 1 ? '' : 's'}';
          } else {
            timeLabel = 'a moment';
          }
          return 'Your account is suspended for $timeLabel.';
        }
        return 'Your account is currently suspended.';
      default:
        return 'Your account is restricted.';
    }
  }
}

// ── App user model ────────────────────────────────────────────────────────────

class AppUser {
  final String        uid;
  final String        email;
  final String        displayName;
  final UserRole      role;
  final AccountStatus status;
  final bool          shadowBanned;
  final DateTime      createdAt;
  final DateTime?     restrictionEndsAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    required this.shadowBanned,
    required this.createdAt,
    this.restrictionEndsAt,
  });

  bool get isModerator  => role == UserRole.moderator;
  bool get isBanned     => status == AccountStatus.banned;
  bool get isSuspended  => status == AccountStatus.suspended;
  bool get canPost      => status.canPost;

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    final rawStatus = data['status'] as String? ?? 'active';

    // A suspension is only active if restrictionEndsAt is in the future.
    // If time has elapsed treat them as active again so they're not
    // permanently locked out without a moderator action.
    final endsAt =
        (data['restrictionEndsAt'] as Timestamp?)?.toDate();
    String effectiveStatus = rawStatus;
    if (rawStatus == 'suspended' &&
        endsAt != null &&
        endsAt.isBefore(DateTime.now())) {
      effectiveStatus = 'active';
    }

    return AppUser(
      uid:              uid,
      email:            data['email']       as String? ?? '',
      displayName:      data['displayName'] as String? ?? '',
      role:             UserRoleExtension.fromString(data['role'] as String?),
      status:           AccountStatusExtension.fromString(effectiveStatus),
      shadowBanned:     data['shadowBanned'] as bool? ?? false,
      createdAt:        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      restrictionEndsAt: endsAt,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'email':       email,
    'displayName': displayName,
    'role':        role.name,
    'createdAt':   Timestamp.fromDate(createdAt),
    // status, shadowBanned, restrictionEndsAt written only by moderator actions
  };
}

// ── Auth result wrapper ───────────────────────────────────────────────────────

class AuthResult {
  final AppUser? user;
  final String?  errorMessage;
  /// Non-null when sign-in was blocked due to a ban or suspension.
  final AccountRestrictedException? restriction;

  const AuthResult.success(this.user)
      : errorMessage = null, restriction = null;
  const AuthResult.failure(this.errorMessage)
      : user = null, restriction = null;
  const AuthResult.restricted(this.restriction)
      : user = null, errorMessage = null;

  bool get isSuccess    => user != null;
  bool get isRestricted => restriction != null;
}

// ── AuthService ───────────────────────────────────────────────────────────────

class AuthService {
  final FirebaseAuth    _auth        = FirebaseAuth.instance;
  final FirebaseFirestore _db        = FirebaseFirestore.instance;
  final GoogleSignIn    _googleSignIn = GoogleSignIn();

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<AppUser?> get appUserStream {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      // On stream emission we do NOT block — the live status stream in
      // AuthProvider handles forced sign-out if status changes while logged in.
      return _fetchAppUser(firebaseUser.uid);
    });
  }

  /// Real-time stream of just the account status for a given uid.
  /// AuthProvider subscribes to this so in-session bans take effect instantly.
  Stream<AccountStatus> statusStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return AccountStatus.active;
      final data   = snap.data()!;
      final endsAt = (data['restrictionEndsAt'] as Timestamp?)?.toDate();
      final raw    = data['status'] as String? ?? 'active';
      // Auto-expire suspensions
      if (raw == 'suspended' && endsAt != null && endsAt.isBefore(DateTime.now())) {
        return AccountStatus.active;
      }
      return AccountStatusExtension.fromString(raw);
    });
  }

  // ── Current user (sync) ───────────────────────────────────────────────────

  User? get currentFirebaseUser => _auth.currentUser;

  Future<AppUser?> get currentAppUser async {
    final u = _auth.currentUser;
    if (u == null) return null;
    return _fetchAppUser(u.uid);
  }

  // ── Sign up ───────────────────────────────────────────────────────────────

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email:    email.trim(),
        password: password,
      );
      await credential.user!.updateDisplayName(displayName.trim());

      final appUser = AppUser(
        uid:         credential.user!.uid,
        email:       email.trim(),
        displayName: displayName.trim(),
        role:        UserRole.user,
        status:      AccountStatus.active,
        shadowBanned: false,
        createdAt:   DateTime.now(),
      );
      await _createUserDocument(appUser);
      return AuthResult.success(appUser);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendlyError(e.code));
    } catch (e) {
      return AuthResult.failure('Something went wrong. Please try again.');
    }
  }

  // ── Sign in ───────────────────────────────────────────────────────────────

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email:    email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      AppUser? appUser = await _fetchAppUser(uid);

      if (appUser == null) {
        appUser = AppUser(
          uid:         uid,
          email:       email.trim(),
          displayName: credential.user!.displayName ?? email.split('@').first,
          role:        UserRole.user,
          status:      AccountStatus.active,
          shadowBanned: false,
          createdAt:   DateTime.now(),
        );
        await _db.collection('users').doc(uid).set(appUser.toFirestore());
      }

      // Block sign-in if banned or suspended
      if (!appUser.status.canSignIn) {
        await _auth.signOut(); // sign out of Firebase Auth immediately
        throw AccountRestrictedException(
          appUser.status,
          restrictionEndsAt: appUser.restrictionEndsAt,
        );
      }

      return AuthResult.success(appUser);
    } on AccountRestrictedException catch (e) {
      return AuthResult.restricted(e);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendlyError(e.code));
    } catch (e) {
      return AuthResult.failure('Something went wrong. Please try again.');
    }
  }

  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) {
        return const AuthResult.failure('Sign-in cancelled.');
      }

      final googleAuth   = await googleAccount.authentication;
      final credential   = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      final userCredential  = await _auth.signInWithCredential(credential);
      final firebaseUser    = userCredential.user!;

      final docSnap = await _db.collection('users').doc(firebaseUser.uid).get();
      AppUser appUser;

      if (!docSnap.exists) {
        appUser = AppUser(
          uid:         firebaseUser.uid,
          email:       firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? 'Guitarist',
          role:        UserRole.user,
          status:      AccountStatus.active,
          shadowBanned: false,
          createdAt:   DateTime.now(),
        );
        await _createUserDocument(appUser);
      } else {
        appUser = AppUser.fromFirestore(docSnap.data()!, firebaseUser.uid);
      }

      // Block sign-in if banned or suspended
      if (!appUser.status.canSignIn) {
        await _auth.signOut();
        await _googleSignIn.signOut();
        throw AccountRestrictedException(
          appUser.status,
          restrictionEndsAt: appUser.restrictionEndsAt,
        );
      }

      return AuthResult.success(appUser);
    } on AccountRestrictedException catch (e) {
      return AuthResult.restricted(e);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendlyError(e.code));
    } catch (e) {
      return AuthResult.failure('Google sign-in failed. Please try again.');
    }
  }

  // ── Password reset ────────────────────────────────────────────────────────

  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendlyError(e.code));
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ── Firestore helpers ─────────────────────────────────────────────────────

  Future<AppUser?> _fetchAppUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromFirestore(doc.data()!, uid);
    } catch (_) {
      return null;
    }
  }

  Future<void> _createUserDocument(AppUser user) async {
    await _db
        .collection('users')
        .doc(user.uid)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  // ── Role stream ───────────────────────────────────────────────────────────

  Stream<UserRole> roleStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return UserRole.user;
      return UserRoleExtension.fromString(snap.data()?['role'] as String?);
    });
  }

  // ── Error messages ────────────────────────────────────────────────────────

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}