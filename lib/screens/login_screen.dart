import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await authService.login(email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
      // AuthState listener in main.dart will navigate automatically
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 40),
            Text('ArtUp', style: GoogleFonts.playfairDisplay(
                fontSize: 40, fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic, color: AppColors.peach)),
            const SizedBox(height: 8),
            Text('Welcome back, artist.', style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.muted)),
            const SizedBox(height: 40),

            _label('Email'),
            const SizedBox(height: 6),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
              decoration: const InputDecoration(hintText: 'you@example.com'),
            ),
            const SizedBox(height: 16),

            _label('Password'),
            const SizedBox(height: 6),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
              decoration: InputDecoration(
                hintText: '••••••••',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.muted, size: 18),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 12),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.errorRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.errorRed))),
                ]),
              ),

            const SizedBox(height: 24),
            GradientButton(label: 'Log In', onPressed: _login, loading: _loading),
            const SizedBox(height: 20),

            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
                    children: [
                      const TextSpan(text: "Don't have an account? "),
                      TextSpan(text: 'Sign up', style: GoogleFonts.dmSans(
                          fontSize: 13, color: AppColors.peach, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t.toUpperCase(),
      style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
          color: AppColors.muted, letterSpacing: 0.5));
}
