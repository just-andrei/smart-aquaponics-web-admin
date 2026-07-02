import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app_theme_controller.dart';
import 'admin_dashboard.dart';
import 'about.dart';
import 'contact.dart';
import 'firebase_options.dart';
import 'public_page_shell.dart';
import 'user_account_service.dart';

class LoginPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const LoginPage({
    super.key,
    this.themeMode = ThemeMode.system,
    this.onThemeChanged = _noopThemeChanged,
  });

  static void _noopThemeChanged(ThemeMode _) {}

  @override
  State<LoginPage> createState() => _LoginPageState();

  static Route createRoute({
    ThemeMode themeMode = ThemeMode.system,
    ValueChanged<ThemeMode> onThemeChanged = _noopThemeChanged,
  }) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          LoginPage(themeMode: themeMode, onThemeChanged: onThemeChanged),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );
      },
    );
  }
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isForgotPasswordMode = false;
  bool _isFirebaseReady = false;
  String? _firebaseInitError;
  String? _loginFieldError;
  String? _resetFieldError;
  late final Future<void> _firebaseInitFuture;

  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _firebaseInitFuture = _initializeFirebase();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      if (!mounted) return;
      setState(() {
        _isFirebaseReady = true;
        _firebaseInitError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFirebaseReady = false;
        _firebaseInitError = e.toString();
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<String> _resolveEmailForUsername(String username) async {
    final resolved = await UserAccountService.resolveEmailForIdentifier(
      username,
    );
    if (resolved != null && resolved.isNotEmpty) return resolved;
    throw FirebaseAuthException(
      code: 'user-not-found',
      message: 'No account found for that email/username/user ID.',
    );
  }

  Future<void> _login() async {
    setState(() => _loginFieldError = null);
    final input = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (input.isEmpty || password.isEmpty) {
      setState(
        () => _loginFieldError = 'Please enter both email and password.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firebaseInitFuture;
      if (_firebaseInitError != null || !_isFirebaseReady) {
        throw FirebaseException(
          plugin: 'firebase_core',
          code: 'app-not-initialized',
          message: 'Firebase is not initialized. $_firebaseInitError',
        );
      }

      String email = input.toLowerCase();
      if (!input.contains('@')) {
        email = await _resolveEmailForUsername(input);
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final signedInUser = FirebaseAuth.instance.currentUser;
      if (signedInUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Authentication succeeded but no session was found.',
        );
      }

      final profileRecord = await UserAccountService.getProfileByUid(
        signedInUser.uid,
      );
      final profile = profileRecord?.data;
      if (profile == null) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'profile-not-found',
          message: 'No Firestore user profile found for this account.',
        );
      }

      final role = UserAccountService.normalizeRole(
        (profile['role'] ?? '').toString(),
      );
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

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              AdminDashboard(
                themeMode: appThemeMode.value,
                onThemeChanged: setAppThemeMode,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        if (mounted) {
          setState(() => _loginFieldError = 'Incorrect email or password.');
        }
      } else {
        _showError(e.message ?? 'Login failed. Please check your credentials.');
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _showError(
          'Access is blocked by Firestore security rules. Please contact admin.',
        );
      } else {
        _showError(e.message ?? 'A Firebase error occurred during login.');
      }
    } on Object catch (e) {
      _showError('Login failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendResetPassword() async {
    setState(() => _resetFieldError = null);
    final input = _usernameController.text.trim();
    if (input.isEmpty) {
      if (_isForgotPasswordMode) {
        setState(() => _resetFieldError = 'Please enter your email address.');
      } else {
        _showError('Enter your email or username first.');
      }
      return;
    }
    if (_isForgotPasswordMode && !input.contains('@')) {
      setState(() => _resetFieldError = 'Please enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firebaseInitFuture;
      if (_firebaseInitError != null || !_isFirebaseReady) {
        throw FirebaseException(
          plugin: 'firebase_core',
          code: 'app-not-initialized',
          message: 'Firebase is not initialized. $_firebaseInitError',
        );
      }
      final email = _isForgotPasswordMode
          ? input.toLowerCase()
          : (input.contains('@')
                ? input.toLowerCase()
                : await _resolveEmailForUsername(input));

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _usernameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset email sent."),
          duration: Duration(seconds: 2),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (_isForgotPasswordMode && e.code == 'invalid-email') {
        if (mounted) {
          setState(
            () => _resetFieldError = 'Please enter a valid email address.',
          );
        }
      } else {
        _showError(e.message ?? 'Failed to send reset email.');
      }
    } on FirebaseException catch (e) {
      _showError(
        e.message ?? 'A Firebase error occurred while sending reset email.',
      );
    } on Object catch (e) {
      _showError('Failed to send reset email: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _enterForgotPasswordMode() {
    setState(() {
      _isForgotPasswordMode = true;
      _usernameController.clear();
      _passwordController.clear();
      _loginFieldError = null;
      _resetFieldError = null;
    });
  }

  void _exitForgotPasswordMode() {
    setState(() {
      _isForgotPasswordMode = false;
      _usernameController.clear();
      _passwordController.clear();
      _loginFieldError = null;
      _resetFieldError = null;
    });
  }

  void _goToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/landing');
  }

  void _navigate(String destination) {
    switch (destination) {
      case 'Home':
        _goToMain();
        break;
      case 'About Us':
        Navigator.of(context).pushReplacement(AboutPage.createRoute());
        break;
      case 'Contact Us':
        Navigator.of(context).pushReplacement(ContactPage.createRoute());
        break;
      case 'Login':
        break;
    }
  }

  void _submitCurrentMode() {
    if (_isLoading || !_isFirebaseReady) {
      return;
    }
    if (_isForgotPasswordMode) {
      _sendResetPassword();
      return;
    }
    _login();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 1200).clamp(0.8, 1.0);
    final eyeIconSize = (24 * scale).clamp(18.0, 24.0);
    final titleFontSize = screenWidth < 700 ? 30.0 : 34.0;
    final bodyFontSize = screenWidth < 700 ? 15.0 : 16.0;
    final cardWidth = screenWidth < 560 ? double.infinity : 470.0;

    return PopScope(
      canPop: !_isForgotPasswordMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isForgotPasswordMode) {
          _goToMain();
        }
      },
      child: PublicPageScaffold(
        currentPage: 'Login',
        onNavigate: _navigate,
        maxContentWidth: 700,
        centerVertically: true,
        child: SizedBox(
          width: cardWidth,
          child: PublicGlassCard(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth < 560 ? 22 : 34,
              vertical: screenWidth < 560 ? 24 : 34,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isForgotPasswordMode ? 'Reset Password' : 'Login',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1D2A24),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isForgotPasswordMode
                      ? 'Enter your registered email and we will send a reset link.'
                      : 'Please sign in with your account details.',
                  style: TextStyle(
                    color: const Color(0xFF66746D),
                    fontSize: bodyFontSize,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  'Email',
                  _usernameController,
                  focusNode: _emailFocusNode,
                  textInputAction: _isForgotPasswordMode
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onSubmitted: (_) {
                    if (_isForgotPasswordMode) {
                      _submitCurrentMode();
                      return;
                    }
                    _passwordFocusNode.requestFocus();
                  },
                  onChanged: (_) {
                    if (_loginFieldError != null) {
                      setState(() => _loginFieldError = null);
                    }
                    if (_resetFieldError != null) {
                      setState(() => _resetFieldError = null);
                    }
                  },
                ),
                if (_isForgotPasswordMode && _resetFieldError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _resetFieldError!,
                    style: const TextStyle(
                      color: Color(0xFFC14A4A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (!_isForgotPasswordMode) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    onChanged: (_) {
                      if (_loginFieldError != null) {
                        setState(() => _loginFieldError = null);
                      }
                    },
                    onSubmitted: (_) => _submitCurrentMode(),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                      color: Color(0xFF1D2A24),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: publicInputDecoration(
                      hintText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: const Color(0xFF66746D),
                          size: eyeIconSize,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  if (_loginFieldError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _loginFieldError!,
                      style: const TextStyle(
                        color: Color(0xFFC14A4A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: (_isLoading || !_isFirebaseReady)
                          ? null
                          : _enterForgotPasswordMode,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1E5D5A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PublicPageButton(
                  label: _isForgotPasswordMode ? 'Reset Password' : 'Login',
                  onPressed: (_isLoading || !_isFirebaseReady)
                      ? null
                      : (_isForgotPasswordMode ? _sendResetPassword : _login),
                  busy: _isLoading,
                  leading: Icon(
                    _isForgotPasswordMode
                        ? Icons.mark_email_read_rounded
                        : Icons.login_rounded,
                    size: 18,
                  ),
                ),
                if (_isForgotPasswordMode) ...[
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _exitForgotPasswordMode,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF66746D),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Back to login'),
                    ),
                  ),
                ],
                if (!_isFirebaseReady && _firebaseInitError == null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Preparing secure sign-in...',
                    style: TextStyle(
                      color: Color(0xFF66746D),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (_firebaseInitError != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to initialize login right now. Please try again shortly.',
                    style: TextStyle(
                      color: Color(0xFFC14A4A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller, {
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      style: const TextStyle(
        color: Color(0xFF1D2A24),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: publicInputDecoration(hintText: hint),
    );
  }
}
