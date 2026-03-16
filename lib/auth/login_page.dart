import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_widgets.dart';
import '../auth/signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _resetSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AuthProvider>().signInWithEmail(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
    // AppRouter listens to authUserStream and redirects automatically.
  }

  Future<void> _googleSignIn() async {
    await context.read<AuthProvider>().signInWithGoogle();
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address first.')),
      );
      return;
    }
    final ok = await context
        .read<AuthProvider>()
        .sendPasswordReset(_emailCtrl.text.trim());
    if (ok && mounted) setState(() => _resetSent = true);
  }

  void _goToSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignupPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ─────────────────────────────────────────
                  const Icon(Icons.music_note,
                      size: 52, color: Colors.white24),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue practising',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.4)),
                  ),
                  const SizedBox(height: 40),

                  // ── Error banner ────────────────────────────────────
                  if (auth.errorMessage != null) ...[
                    AuthErrorBanner(
                      message: auth.errorMessage!,
                      onDismiss: context.read<AuthProvider>().clearError,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Reset confirmation ──────────────────────────────
                  if (_resetSent) ...[
                    AuthInfoBanner(
                      message:
                          'Reset email sent to ${_emailCtrl.text.trim()}',
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Email ───────────────────────────────────────────
                  AuthField(
                    controller: _emailCtrl,
                    label: 'Email',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Password ────────────────────────────────────────
                  AuthField(
                    controller: _passwordCtrl,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white38,
                        size: 20,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required';
                      }
                      return null;
                    },
                  ),

                  // ── Forgot password ─────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed:
                          auth.isLoading ? null : _forgotPassword,
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 8)),
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.45)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Sign in button ──────────────────────────────────
                  AuthPrimaryButton(
                    label: 'Sign In',
                    isLoading: auth.isLoading,
                    onPressed: _signIn,
                  ),
                  const SizedBox(height: 16),

                  const AuthOrDivider(),
                  const SizedBox(height: 16),

                  // ── Google ──────────────────────────────────────────
                  AuthGoogleButton(
                    isLoading: auth.isLoading,
                    onPressed: _googleSignIn,
                  ),
                  const SizedBox(height: 32),

                  // ── Sign up link ────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: _goToSignup,
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}