import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'aquaponics_colors.dart';
import 'user_account_service.dart';

const _teal = Color(0xFF0097A7);

class SignInPage extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ThemeMode themeMode;

  const SignInPage({
    super.key,
    required this.onThemeModeChanged,
    required this.themeMode,
  });

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String> _resolveEmailForUsername(String username) async {
    final resolved = await UserAccountService.resolveEmailForIdentifier(username);
    if (resolved != null && resolved.isNotEmpty) return resolved;
    throw FirebaseAuthException(
      code: 'user-not-found',
      message: 'No account found for that email/username/user ID.',
    );
  }

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    try {
      final input = _emailController.text.trim();
      String email = input.toLowerCase();
      if (!input.contains('@')) {
        email = await _resolveEmailForUsername(input);
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      final signedInUser = FirebaseAuth.instance.currentUser;
      if (signedInUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Authentication succeeded but no session was found.',
        );
      }

      final profileRecord = await UserAccountService.getProfileByUid(signedInUser.uid);
      final profile = profileRecord?.data;
      if (profile == null) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'profile-not-found',
          message: 'No Firestore user profile found for this account.',
        );
      }

      final role = UserAccountService.normalizeRole((profile['role'] ?? '').toString());
      final status = (profile['status'] ?? 'active').toString().toLowerCase();

      if (status != 'active') {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'account-inactive',
          message: 'Your account is inactive. Contact your admin.',
        );
      }

      if (UserAccountService.isGrowerRole(role)) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'access-denied',
          message: 'Grower accounts cannot access this web admin panel.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Authentication failed'),
            backgroundColor: AquaponicsColors.statusDanger,
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'A Firebase error occurred'),
            backgroundColor: AquaponicsColors.statusDanger,
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            backgroundColor: AquaponicsColors.statusDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendResetPassword() async {
    try {
      final input = _emailController.text.trim();
      if (input.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-input',
          message: 'Enter your email or username first.',
        );
      }
      final email = input.contains('@')
          ? input.toLowerCase()
          : await _resolveEmailForUsername(input);
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to send reset email'),
          backgroundColor: AquaponicsColors.statusDanger,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'A Firebase error occurred while sending reset email'),
          backgroundColor: AquaponicsColors.statusDanger,
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reset email: $e'),
          backgroundColor: AquaponicsColors.statusDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AquaponicsColors.primaryBackground,
              AquaponicsColors.secondaryBackground,
              AquaponicsColors.gradientAccent,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: isMobile ? double.infinity : 400,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AquaponicsColors.glassPanel,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AquaponicsColors.subtleBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: _teal, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.water_drop,
                            size: 60,
                            color: _teal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [
                                AquaponicsColors.primaryAccent,
                                AquaponicsColors.brandGradientHeader
                              ],
                            ).createShader(const Rect.fromLTWH(0, 0, 200, 24)),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to monitor your system',
                        style: TextStyle(
                          color: AquaponicsColors.textSecondary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _buildTextField(
                        controller: _emailController,
                        hint: 'Email or Username',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _sendResetPassword,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: _teal,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleAuth,
                          style: FilledButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? !_isPasswordVisible : false,
      enableSuggestions: !isPassword,
      autocorrect: !isPassword,
      keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.emailAddress,
      style: const TextStyle(
        color: Color(0xFF1F2937),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: _teal),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF546E7A),
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              )
            : null,
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF546E7A),
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _teal, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _teal, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _teal, width: 2.8),
        ),
      ),
    );
  }
}
