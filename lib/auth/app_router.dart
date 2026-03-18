import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import 'auth_provider.dart';
import 'login_page.dart';
import 'signup_page.dart';
import '../ui/user_home_page.dart';
import '../ui/metronome_page.dart';
import '../chords/chord_list_page.dart';
import '../ui/guitar_tuner_page.dart';
import '../forum/moderator_dashboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppRouter — single widget that decides what to show based on auth state.
// ─────────────────────────────────────────────────────────────────────────────

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Still resolving Firebase auth state on startup.
    if (auth.isLoading) {
      return const _SplashScreen();
    }

    // Not signed in → show login.
    if (!auth.isSignedIn) {
      return const LoginPage();
    }

    // Signed in but banned — hard block, cannot proceed.
    if (auth.isBanned) {
      return const _BannedScreen();
    }

    // Signed in but suspended — time-limited block.
    if (auth.isSuspended) {
      return _SuspendedScreen(
        endsAt: auth.appUser?.restrictionEndsAt,
      );
    }

    // Signed in and allowed → route by role.
    return auth.isModerator
        ? const ModeratorDashboardPage()
        : const MainShell();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BannedScreen
// ─────────────────────────────────────────────────────────────────────────────

class _BannedScreen extends StatelessWidget {
  const _BannedScreen();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.block_rounded,
                    size: 38, color: Colors.redAccent),
              ),
              const SizedBox(height: 28),
              const Text(
                'Account Banned',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Your account has been permanently banned '
                'for violating our community guidelines.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.5),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => auth.signOut(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    'Sign out',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SuspendedScreen
// ─────────────────────────────────────────────────────────────────────────────

class _SuspendedScreen extends StatelessWidget {
  final DateTime? endsAt;
  const _SuspendedScreen({this.endsAt});

  String get _timeRemaining {
    if (endsAt == null || endsAt!.isBefore(DateTime.now())) return '';
    final diff = endsAt!.difference(DateTime.now());
    if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} remaining';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} remaining';
    }
    if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} remaining';
    }
    return 'less than a minute remaining';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.orangeAccent.withOpacity(0.4),
                      width: 1.5),
                ),
                child: const Icon(Icons.pause_circle_outline_rounded,
                    size: 38, color: Colors.orangeAccent),
              ),
              const SizedBox(height: 28),
              const Text(
                'Account Suspended',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Your account has been temporarily suspended '
                'for violating our community guidelines.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.5),
              ),
              if (_timeRemaining.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 15, color: Colors.orangeAccent),
                      const SizedBox(width: 8),
                      Text(
                        _timeRemaining,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => auth.signOut(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    'Sign out',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SplashScreen
// ─────────────────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 56, color: Colors.white24),
            SizedBox(height: 24),
            CircularProgressIndicator(strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Named route constants
// ─────────────────────────────────────────────────────────────────────────────

class AppRoutes {
  static const String login     = '/login';
  static const String signup    = '/signup';
  static const String home      = '/home';
  static const String moderator = '/moderator';

  static Map<String, WidgetBuilder> get routes => {
    login:     (_) => const LoginPage(),
    signup:    (_) => const SignupPage(),
    home:      (_) => const MainShell(),
    moderator: (_) => const ModeratorDashboardPage(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// RoleGate / ModeratorOnly helpers — unchanged
// ─────────────────────────────────────────────────────────────────────────────

class RoleGate extends StatelessWidget {
  final UserRole role;
  final Widget   child;
  final Widget?  fallback;

  const RoleGate({
    super.key,
    required this.role,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasPermission =
        auth.role == role || (role == UserRole.user);
    return hasPermission ? child : (fallback ?? const SizedBox.shrink());
  }
}

class ModeratorOnly extends StatelessWidget {
  final Widget  child;
  final Widget? fallback;
  const ModeratorOnly({super.key, required this.child, this.fallback});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.isModerator ? child : (fallback ?? const SizedBox.shrink());
  }
}