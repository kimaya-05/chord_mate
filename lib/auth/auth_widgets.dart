import 'package:flutter/material.dart';

class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
        prefixIcon:
            Icon(icon, color: Colors.white.withOpacity(0.3), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF13131A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Colors.greenAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle:
            const TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent.shade700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white10,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class AuthGoogleButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const AuthGoogleButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF13131A),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('G',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4285F4))),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child:
              Divider(color: Colors.white.withOpacity(0.1), height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('or',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withOpacity(0.3))),
      ),
      Expanded(
          child:
              Divider(color: Colors.white.withOpacity(0.1), height: 1)),
    ]);
  }
}

class AuthErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const AuthErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.redAccent.withOpacity(0.4), width: 1),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline,
            color: Colors.redAccent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: Colors.redAccent, fontSize: 13)),
        ),
        GestureDetector(
          onTap: onDismiss,
          child: const Icon(Icons.close,
              color: Colors.redAccent, size: 18),
        ),
      ]),
    );
  }
}

class AuthInfoBanner extends StatelessWidget {
  final String message;

  const AuthInfoBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.greenAccent.withOpacity(0.3), width: 1),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline,
            color: Colors.greenAccent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: Colors.greenAccent, fontSize: 13)),
        ),
      ]),
    );
  }
}