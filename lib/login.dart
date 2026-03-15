import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'admin_dashboard.dart';
import 'firebase_options.dart';
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

  @override
  void initState() {
    super.initState();
    _firebaseInitFuture = _initializeFirebase();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
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
                themeMode: widget.themeMode,
                onThemeChanged: widget.onThemeChanged,
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

  Future<void> _onBackPressed() async {
    if (_isForgotPasswordMode) {
      _goToMain();
      return;
    }
    _goToMain();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 1200).clamp(0.6, 1.0);
    final backFontSize = (16 * scale).clamp(11.0, 16.0);
    final backIconSize = (24 * scale).clamp(16.0, 24.0);
    final eyeIconSize = (24 * scale).clamp(16.0, 24.0);
    final headerFontSize = (22 * scale).clamp(14.0, 22.0);
    final titleFontSize = (28 * scale).clamp(18.0, 28.0);
    final fieldFontSize = (16 * scale).clamp(11.0, 16.0);
    final buttonFontSize = (16 * scale).clamp(11.0, 16.0);

    return PopScope(
      canPop: !_isForgotPasswordMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isForgotPasswordMode) {
          _goToMain();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // BACKGROUND IMAGE
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('image/aquaponics.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // DARK OVERLAY
            Container(color: Colors.black.withOpacity(0.4)),

            Column(
              children: [
                // HEADER
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0f2027).withOpacity(0.92),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: _onBackPressed,
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: backIconSize,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Back",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: backFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "Aquaponics",
                        style: TextStyle(
                          fontSize: headerFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),

                // CENTERED LOGIN BOX
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      bool isSmallScreen = constraints.maxWidth < 600;

                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Align(
                            alignment: const Alignment(0, -0.2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 50,
                              ),
                              margin: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 20 : 0,
                                vertical: 0,
                              ),
                              width: isSmallScreen ? double.infinity : 450,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0f2027).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isForgotPasswordMode
                                        ? "Reset Password"
                                        : "Login",
                                    style: TextStyle(
                                      fontSize: titleFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _isForgotPasswordMode
                                        ? "Enter your registered email and we will send a reset link."
                                        : "Please sign in with your account details.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: (14 * scale).clamp(10.0, 14.0),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildTextField(
                                    _isForgotPasswordMode ? "Email" : "Email",
                                    _usernameController,
                                    fieldFontSize,
                                    onChanged: (_) {
                                      if (_loginFieldError != null) {
                                        setState(() => _loginFieldError = null);
                                      }
                                      if (_resetFieldError != null) {
                                        setState(() => _resetFieldError = null);
                                      }
                                    },
                                  ),
                                  if (_isForgotPasswordMode &&
                                      _resetFieldError != null) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _resetFieldError!,
                                        style: TextStyle(
                                          color: const Color(0xFFFF8A8A),
                                          fontSize: (13 * scale).clamp(
                                            10.0,
                                            13.0,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (!_isForgotPasswordMode) ...[
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _passwordController,
                                      onChanged: (_) {
                                        if (_loginFieldError != null) {
                                          setState(
                                            () => _loginFieldError = null,
                                          );
                                        }
                                      },
                                      obscureText: _obscurePassword,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: fieldFontSize,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Password",
                                        hintStyle: TextStyle(
                                          color: Colors.white54,
                                          fontSize: fieldFontSize,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(
                                          0.08,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: Colors.white70,
                                            size: eyeIconSize,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    if (_loginFieldError != null) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _loginFieldError!,
                                          style: TextStyle(
                                            color: const Color(0xFFFF8A8A),
                                            fontSize: (13 * scale).clamp(
                                              10.0,
                                              13.0,
                                            ),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed:
                                            (_isLoading || !_isFirebaseReady)
                                            ? null
                                            : _enterForgotPasswordMode,
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.tealAccent,
                                          textStyle: TextStyle(
                                            fontSize: (14 * scale).clamp(
                                              10.0,
                                              14.0,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text('Forget Password?'),
                                      ),
                                    ),
                                  ],
                                  SizedBox(
                                    height: _isForgotPasswordMode ? 20 : 24,
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.tealAccent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                      ),
                                      onPressed:
                                          (_isLoading || !_isFirebaseReady)
                                          ? null
                                          : (_isForgotPasswordMode
                                                ? _sendResetPassword
                                                : _login),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black,
                                              ),
                                            )
                                          : Text(
                                              _isForgotPasswordMode
                                                  ? "Reset Password"
                                                  : "Login",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: buttonFontSize,
                                              ),
                                            ),
                                    ),
                                  ),
                                  if (_isForgotPasswordMode) ...[
                                    const SizedBox(height: 26),
                                    TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _exitForgotPasswordMode,
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        textStyle: TextStyle(
                                          fontSize: (14 * scale).clamp(
                                            10.0,
                                            14.0,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Back to login'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller,
    double fontSize, {
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: Colors.white, fontSize: fontSize),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white54, fontSize: fontSize),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
