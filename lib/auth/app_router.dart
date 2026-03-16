import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import 'auth_provider.dart';
import 'login_page.dart';
import 'signup_page.dart';
import '../ui/metronome_page.dart';
import '../chords/chord_list_page.dart';
import '../ui/guitar_tuner_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder screens — replace with your real pages.
// ─────────────────────────────────────────────────────────────────────────────

class UserHomePage extends StatelessWidget {
  const UserHomePage({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderPage(
        label: 'Home',
        icon: Icons.music_note,
      );
}

class ModeratorDashboardPage extends StatelessWidget {
  const ModeratorDashboardPage({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderPage(
        label: 'Moderator Dashboard',
        icon: Icons.admin_panel_settings,
      );
}

class _PlaceholderPage extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlaceholderPage({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(label),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Signed in as ${auth.appUser?.displayName ?? '—'}\n'
              'Role: ${auth.role.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppRouter  — the single widget that decides what to show.
//
// Mount this as the home of your MaterialApp:
//
//   MaterialApp(
//     home: const AppRouter(),
//     ...
//   )
//
// or via routes if you prefer named routing — AppRouter works either way.
// ─────────────────────────────────────────────────────────────────────────────

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuitarTunerPage();
    // final auth = context.watch<AuthProvider>();

    // // Still resolving Firebase auth state on startup.
    // if (auth.isLoading) {
    //   return const _SplashScreen();
    // }

    // // Not signed in → show login.
    // if (!auth.isSignedIn) {
    //   return const LoginPage();
    // }

    // // Signed in → route by role.
    // return auth.isModerator
    //     ? const ModeratorDashboardPage()
    //     : const UserHomePage();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Splash / loading screen shown while Firebase resolves auth state.
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
// Named route constants — use these instead of raw strings everywhere.
// ─────────────────────────────────────────────────────────────────────────────

class AppRoutes {
  static const String login    = '/login';
  static const String signup   = '/signup';
  static const String home     = '/home';
  static const String moderator = '/moderator';

  static Map<String, WidgetBuilder> get routes => {
    login:     (_) => const LoginPage(),
    signup:    (_) => const SignupPage(),
    home:      (_) => const UserHomePage(),
    moderator: (_) => const ModeratorDashboardPage(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// RoleGate widget — wrap any widget that should only be visible to moderators.
//
// Usage:
//   RoleGate(
//     role: UserRole.moderator,
//     child: DeleteUserButton(),
//     fallback: Text('No permission'),  // optional
//   )
// ─────────────────────────────────────────────────────────────────────────────

class RoleGate extends StatelessWidget {
  final UserRole role;
  final Widget child;
  final Widget? fallback;

  const RoleGate({
    super.key,
    required this.role,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasPermission = auth.role == role ||
        (role == UserRole.user); // users can see user-level content
    return hasPermission ? child : (fallback ?? const SizedBox.shrink());
  }
}

// Convenience shorthand for moderator-only widgets.
class ModeratorOnly extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  const ModeratorOnly({super.key, required this.child, this.fallback});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.isModerator ? child : (fallback ?? const SizedBox.shrink());
  }
}