import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl   = TextEditingController();
  final _handleCtrl = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _register() async {
    final name   = _nameCtrl.text.trim();
    final handle = _handleCtrl.text.trim().replaceAll('@', '').replaceAll(' ', '_');
    final email  = _emailCtrl.text.trim();
    final pass   = _passCtrl.text.trim();

    if (name.isEmpty || handle.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await authService.register(
        email: email, password: pass, handle: handle, fullName: name,
      );
      if (mounted) Navigator.of(context).pop();
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
    _nameCtrl.dispose(); _handleCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.dark, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Join ArtUp', style: GoogleFonts.playfairDisplay(
                fontSize: 32, fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic, color: AppColors.peach)),
            const SizedBox(height: 6),
            Text('Share your art with the world.', style: GoogleFonts.dmSans(fontSize: 15, color: AppColors.muted)),
            const SizedBox(height: 32),

            _label('Full Name'),
            const SizedBox(height: 6),
            TextField(controller: _nameCtrl,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
                decoration: const InputDecoration(hintText: 'Your name')),
            const SizedBox(height: 14),

            _label('Handle'),
            const SizedBox(height: 6),
            TextField(
              controller: _handleCtrl,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
              decoration: const InputDecoration(
                hintText: 'your_handle',
                prefixText: '@',
                prefixStyle: TextStyle(color: AppColors.peach, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 14),

            _label('Email'),
            const SizedBox(height: 6),
            TextField(controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
                decoration: const InputDecoration(hintText: 'you@example.com')),
            const SizedBox(height: 14),

            _label('Password'),
            const SizedBox(height: 6),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
              decoration: InputDecoration(
                hintText: 'Min. 6 characters',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.muted, size: 18),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
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
            GradientButton(label: 'Create Account', onPressed: _register, loading: _loading),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t.toUpperCase(),
      style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
          color: AppColors.muted, letterSpacing: 0.5));
}
