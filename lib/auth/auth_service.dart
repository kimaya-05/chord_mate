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

// ── App user model ────────────────────────────────────────────────────────────

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
  });

  bool get isModerator => role == UserRole.moderator;

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: UserRoleExtension.fromString(data['role'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'displayName': displayName,
        'role': role.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ── Auth result wrapper ───────────────────────────────────────────────────────

class AuthResult {
  final AppUser? user;
  final String? errorMessage;

  const AuthResult.success(this.user) : errorMessage = null;
  const AuthResult.failure(this.errorMessage) : user = null;

  bool get isSuccess => user != null;
}

// ── AuthService ───────────────────────────────────────────────────────────────

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Emits the current [AppUser] (with role) on every auth state change,
  /// or null when signed out.
  Stream<AppUser?> get appUserStream {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return _fetchAppUser(firebaseUser.uid);
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
        email: email.trim(),
        password: password,
      );

      await credential.user!.updateDisplayName(displayName.trim());

      final appUser = AppUser(
        uid: credential.user!.uid,
        email: email.trim(),
        displayName: displayName.trim(),
        role: UserRole.user, // all new accounts start as user
        createdAt: DateTime.now(),
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
        email: email.trim(),
        password: password,
      );
      final appUser = await _fetchAppUser(credential.user!.uid);
      if (appUser == null) {
        return const AuthResult.failure('Account data not found. Please contact support.');
      }
      return AuthResult.success(appUser);
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
        // User cancelled the picker.
        return const AuthResult.failure('Sign-in cancelled.');
      }

      final googleAuth = await googleAccount.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user!;

      // Create Firestore document on first Google sign-in.
      final docSnap = await _db.collection('users').doc(firebaseUser.uid).get();
      if (!docSnap.exists) {
        final appUser = AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? 'Guitarist',
          role: UserRole.user,
          createdAt: DateTime.now(),
        );
        await _createUserDocument(appUser);
        return AuthResult.success(appUser);
      }

      final appUser = await _fetchAppUser(firebaseUser.uid);
      return AuthResult.success(appUser!);
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

  // ── Role check (real-time) ────────────────────────────────────────────────

  /// Listen to role changes in real time (useful if admin promotes a user
  /// while they are already logged in).
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