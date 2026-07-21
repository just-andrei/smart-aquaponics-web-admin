import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_theme_controller.dart';
import 'admin_dashboard.dart';
import 'aquaponics_colors.dart';
import 'about.dart';
import 'contact.dart';
import 'firebase_options.dart';
import 'inquire.dart';
import 'login.dart';
import 'user_account_service.dart';

void main() {
  runApp(const AquaponicsApp());
}

class AquaponicsApp extends StatefulWidget {
  const AquaponicsApp({super.key});

  @override
  State<AquaponicsApp> createState() => _AquaponicsAppState();
}

class _AquaponicsAppState extends State<AquaponicsApp> {
  void _handleThemeChanged(ThemeMode mode) {
    setAppThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Aquaponics',
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AquaponicsColors.mossGreen,
              primary: AquaponicsColors.mossGreen,
              secondary: AquaponicsColors.deepTeal,
              surface: AquaponicsColors.offWhite,
            ),
            scaffoldBackgroundColor: AquaponicsColors.greenhouseBackground,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AquaponicsColors.mossGreen,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: AppEntryPage(
            themeMode: themeMode,
            onThemeChanged: _handleThemeChanged,
          ),
          onGenerateRoute: (settings) {
            if (settings.name == '/' || settings.name == '/landing') {
              return PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (context, animation, secondaryAnimation) =>
                    LandingPage(
                      themeMode: themeMode,
                      onThemeChanged: _handleThemeChanged,
                    ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    ),
                    child: child,
                  );
                },
              );
            }
            if (settings.name == '/login') {
              return LoginPage.createRoute(
                themeMode: themeMode,
                onThemeChanged: _handleThemeChanged,
              );
            }
            return null;
          },
        );
      },
    );
  }
}

class AppEntryPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const AppEntryPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<AppEntryPage> createState() => _AppEntryPageState();
}

class _AppEntryPageState extends State<AppEntryPage> {
  late final Future<void> _firebaseInitFuture = _initializeFirebase();

  Future<void> _initializeFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  Future<void> _signOutToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      LoginPage.createRoute(
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _firebaseInitFuture,
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (initSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to initialize the web app: ${initSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final currentUser = authSnapshot.data;
            if (currentUser == null) {
              return LandingPage(
                themeMode: widget.themeMode,
                onThemeChanged: widget.onThemeChanged,
              );
            }

            return FutureBuilder<UserSessionAccess>(
              future: UserAccountService.resolveSessionAccessForUser(
                currentUser,
              ),
              builder: (context, accessSnapshot) {
                if (accessSnapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (accessSnapshot.hasError) {
                  return _SessionBlockedView(
                    message:
                        'Unable to verify your web access right now. Please sign in again.',
                    onPressed: _signOutToLogin,
                    actionLabel: 'Sign Out',
                  );
                }

                final access =
                    accessSnapshot.data ??
                    const UserSessionAccess(
                      uid: '',
                      email: '',
                      role: 'unknown',
                      status: 'inactive',
                      sourceCollection: '',
                      profileData: null,
                    );

                if (access.isAdmin && access.isActive) {
                  return AdminDashboard(
                    themeMode: widget.themeMode,
                    onThemeChanged: widget.onThemeChanged,
                  );
                }

                final message = !access.isActive
                    ? 'Your account is inactive. Contact an admin before using the web dashboard.'
                    : 'This web app is for admin accounts only. Grower accounts should use the separate mobile app.';

                return _SessionBlockedView(
                  message: message,
                  onPressed: _signOutToLogin,
                  actionLabel: 'Sign Out',
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SessionBlockedView extends StatelessWidget {
  final String message;
  final Future<void> Function() onPressed;
  final String actionLabel;

  const _SessionBlockedView({
    required this.message,
    required this.onPressed,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 56),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => onPressed(),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LandingPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const LandingPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showChallenges = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_showChallenges && _scrollController.offset > 10) {
      setState(() {
        _showChallenges = true;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 640;
    final isNarrow = screenWidth < 900;
    final isCompactHeight = screenHeight < 700;

    final brandFontSize = isNarrow ? 18.0 : 22.0;
    final navFontSize = isNarrow ? 14.0 : 16.0;
    final heroTitleFontSize = isMobile
        ? (isCompactHeight ? 30.0 : 34.0)
        : isNarrow
        ? 40.0
        : 48.0;
    final heroSubtitleFontSize = isMobile ? 15.5 : 19.0;
    final buttonFontSize = 16.0;
    final buttonWidth = isMobile
        ? (screenWidth - 40).clamp(220.0, 260.0).toDouble()
        : 220.0;
    final challengeTitleFontSize = isNarrow ? 24.0 : 32.0;
    final challengeItemFontSize = isNarrow ? 16.0 : 18.0;
    final sectionTitleSize = isNarrow ? 26.0 : 34.0;
    final sectionBodySize = isNarrow ? 16.0 : 17.0;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewportHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : screenHeight;
          final heroMinHeight = isMobile
              ? (isCompactHeight ? 620.0 : 680.0)
              : viewportHeight < 760
              ? 620.0
              : viewportHeight * 0.82;
          final heroHorizontalPadding = isMobile
              ? 20.0
              : isNarrow
              ? 32.0
              : 72.0;
          final heroTopPadding = isMobile ? 116.0 : 132.0;
          final heroBottomPadding = isCompactHeight ? 36.0 : 64.0;

          return Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    Container(
                      constraints: BoxConstraints(minHeight: heroMinHeight),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage('image/aquaponics.png'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(
                                      0xFFF7FBF7,
                                    ).withValues(alpha: 0.88),
                                    const Color(
                                      0xFFEFF7F2,
                                    ).withValues(alpha: 0.48),
                                    const Color(
                                      0xFF123C35,
                                    ).withValues(alpha: 0.16),
                                  ],
                                  stops: const [0.0, 0.48, 1.0],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              heroHorizontalPadding,
                              heroTopPadding,
                              heroHorizontalPadding,
                              heroBottomPadding,
                            ),
                            child: Row(
                              mainAxisAlignment: isNarrow
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isNarrow ? 620 : 650,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: isNarrow
                                          ? CrossAxisAlignment.center
                                          : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Hybrid Power-Driven Aquaponics Control Center',
                                          textAlign: isNarrow
                                              ? TextAlign.center
                                              : TextAlign.left,
                                          style: TextStyle(
                                            fontSize: heroTitleFontSize,
                                            fontWeight: FontWeight.w800,
                                            color:
                                                AquaponicsColors.greenhouseText,
                                            height: 1.12,
                                          ),
                                        ),
                                        const SizedBox(height: 15),
                                        Text(
                                          'Real-time IoT monitoring for water quality, fish and plant health, alerts, feeding records, and solar battery backup in one field-ready system.',
                                          textAlign: isNarrow
                                              ? TextAlign.center
                                              : TextAlign.left,
                                          style: TextStyle(
                                            fontSize: heroSubtitleFontSize,
                                            color:
                                                AquaponicsColors.greenhouseText,
                                            height: 1.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(
                                          height: isCompactHeight ? 16 : 22,
                                        ),
                                        _buildHeroFeatureCards(
                                          isNarrow: isNarrow,
                                          bodySize: isMobile ? 14.0 : 15.0,
                                        ),
                                        SizedBox(
                                          height: isCompactHeight ? 20 : 28,
                                        ),
                                        Align(
                                          alignment: isNarrow
                                              ? Alignment.center
                                              : Alignment.centerLeft,
                                          child: SizedBox(
                                            width: buttonWidth,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 30,
                                                      vertical: 18,
                                                    ),
                                                backgroundColor:
                                                    AquaponicsColors.mossGreen,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                ),
                                              ),
                                              onPressed: () {
                                                Navigator.of(context).push(
                                                  InquirePage.createRoute(),
                                                );
                                              },
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.forum_rounded,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Request Demo',
                                                    style: TextStyle(
                                                      fontSize: buttonFontSize,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 350),
                      opacity: _showChallenges ? 1 : 0,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        offset: _showChallenges
                            ? Offset.zero
                            : const Offset(0, 0.06),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 50,
                          ),
                          color: const Color(0xFF173128),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 900),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Problems Growers Face in the Field',
                                    style: TextStyle(
                                      fontSize: challengeTitleFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  _buildChallengeItem(
                                    'Unstable pH, oxygen, temperature, and turbidity',
                                    challengeItemFontSize,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildChallengeItem(
                                    'Flooding and saltwater intrusion that can damage fish and plants',
                                    challengeItemFontSize,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildChallengeItem(
                                    'Manual monitoring that takes time and delays action',
                                    challengeItemFontSize,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildChallengeItem(
                                    'Power outages that interrupt pumps, aeration, and feeding routines',
                                    challengeItemFontSize,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildSmartHybridSolution(
                      isNarrow: isNarrow,
                      titleSize: sectionTitleSize,
                      bodySize: sectionBodySize,
                    ),
                    _buildHowItWorks(
                      isNarrow: isNarrow,
                      titleSize: sectionTitleSize,
                      bodySize: sectionBodySize,
                    ),
                    _buildKeyFeatures(
                      isNarrow: isNarrow,
                      titleSize: sectionTitleSize,
                      bodySize: sectionBodySize,
                    ),
                    _buildWhyChoose(
                      isNarrow: isNarrow,
                      titleSize: sectionTitleSize,
                      bodySize: sectionBodySize,
                    ),
                    _buildAboutLytra(
                      titleSize: sectionTitleSize,
                      bodySize: sectionBodySize,
                    ),
                    _buildCallToAction(titleSize: sectionTitleSize),
                    _buildFooter(isNarrow: isNarrow, bodySize: sectionBodySize),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.86),
                    border: Border(
                      bottom: const BorderSide(
                        color: AquaponicsColors.adminBorder,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Aquaponics',
                              style: TextStyle(
                                fontSize: brandFontSize,
                                fontWeight: FontWeight.w800,
                                color: AquaponicsColors.greenhouseText,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (!isNarrow) ...[
                              NavItem(
                                title: 'About Us',
                                fontSize: navFontSize,
                                themeMode: widget.themeMode,
                                onThemeChanged: widget.onThemeChanged,
                              ),
                              const SizedBox(width: 28),
                              NavItem(
                                title: 'Contact Us',
                                fontSize: navFontSize,
                                themeMode: widget.themeMode,
                                onThemeChanged: widget.onThemeChanged,
                              ),
                              const SizedBox(width: 28),
                              NavItem(
                                title: 'Login',
                                fontSize: navFontSize,
                                themeMode: widget.themeMode,
                                onThemeChanged: widget.onThemeChanged,
                              ),
                            ] else
                              PopupMenuButton<String>(
                                tooltip: 'Open navigation menu',
                                icon: const Icon(Icons.menu_rounded),
                                onSelected: (value) {
                                  if (value == 'About Us') {
                                    Navigator.of(
                                      context,
                                    ).push(AboutPage.createRoute());
                                  } else if (value == 'Contact Us') {
                                    Navigator.of(
                                      context,
                                    ).push(ContactPage.createRoute());
                                  } else if (value == 'Login') {
                                    Navigator.of(context).push(
                                      LoginPage.createRoute(
                                        themeMode: widget.themeMode,
                                        onThemeChanged: widget.onThemeChanged,
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'About Us',
                                    child: Text('About Us'),
                                  ),
                                  PopupMenuItem(
                                    value: 'Contact Us',
                                    child: Text('Contact Us'),
                                  ),
                                  PopupMenuItem(
                                    value: 'Login',
                                    child: Text('Login'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSmartHybridSolution({
    required bool isNarrow,
    required double titleSize,
    required double bodySize,
  }) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFEAF1F6),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Real-Time IoT Monitoring with Hybrid Solar Backup',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: AquaponicsColors.greenhouseText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The system combines aquaponics, environmental sensors, controller automation, and backup power so operators can respond before fish, plants, or pumps are at risk.',
                style: TextStyle(
                  fontSize: bodySize,
                  color: AquaponicsColors.greenhouseSubtext,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildTagCard(
                    'Water quality and environment readings',
                    bodySize,
                    Icons.sensors_rounded,
                  ),
                  _buildTagCard(
                    'Hybrid grid, solar, and battery resilience',
                    bodySize,
                    Icons.battery_charging_full_rounded,
                  ),
                  _buildTagCard(
                    'Alerts with recommended action',
                    bodySize,
                    Icons.warning_amber_rounded,
                  ),
                  _buildTagCard(
                    'Grower records, reports, and support',
                    bodySize,
                    Icons.assignment_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDDE4EA)),
                ),
                child: isNarrow
                    ? Column(
                        children: [
                          const _DiagramNode(label: 'Sensors'),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Icon(
                              Icons.arrow_downward,
                              color: Color(0xFF3F4A5A),
                            ),
                          ),
                          const _DiagramNode(label: 'IoT Controller'),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Icon(
                              Icons.arrow_downward,
                              color: Color(0xFF3F4A5A),
                            ),
                          ),
                          const _DiagramNode(label: 'Power + Controls'),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Icon(
                              Icons.arrow_downward,
                              color: Color(0xFF3F4A5A),
                            ),
                          ),
                          const _DiagramNode(label: 'Dashboard'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: _DiagramNode(label: 'Sensors')),
                          Icon(Icons.arrow_forward, color: Color(0xFF3F4A5A)),
                          Expanded(
                            child: _DiagramNode(label: 'IoT Controller'),
                          ),
                          Icon(Icons.arrow_forward, color: Color(0xFF3F4A5A)),
                          Expanded(
                            child: _DiagramNode(label: 'Power + Controls'),
                          ),
                          Icon(Icons.arrow_forward, color: Color(0xFF3F4A5A)),
                          Expanded(child: _DiagramNode(label: 'Dashboard')),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorks({
    required bool isNarrow,
    required double titleSize,
    required double bodySize,
  }) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How It Helps Operators Act Faster',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: AquaponicsColors.greenhouseText,
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildStepCard(
                    'Step 1',
                    'Sensors read pH, temperature, turbidity, oxygen, and humidity',
                    bodySize,
                    isNarrow,
                  ),
                  _buildStepCard(
                    'Step 2',
                    'The controller sends updates to the dashboard in real time',
                    bodySize,
                    isNarrow,
                  ),
                  _buildStepCard(
                    'Step 3',
                    'Alerts explain the risk and the next practical action',
                    bodySize,
                    isNarrow,
                  ),
                  _buildStepCard(
                    'Step 4',
                    'Reports and records keep feeding, growth, and support work organized',
                    bodySize,
                    isNarrow,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyFeatures({
    required bool isNarrow,
    required double titleSize,
    required double bodySize,
  }) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFEAF1F6),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Field-Ready Features',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: AquaponicsColors.greenhouseText,
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildFeatureCard(
                    'Water Monitoring',
                    'pH, water temperature, dissolved oxygen, turbidity, and humidity are presented in large readable cards.',
                    bodySize,
                    isNarrow,
                    Icons.water_drop_rounded,
                  ),
                  _buildFeatureCard(
                    'Alerts',
                    'Warnings and critical events include current readings, safe ranges, and recommended action.',
                    bodySize,
                    isNarrow,
                    Icons.notifications_active_rounded,
                  ),
                  _buildFeatureCard(
                    'Feeding',
                    'Feeding schedules and operating notes stay visible for day-to-day fish care.',
                    bodySize,
                    isNarrow,
                    Icons.restaurant_rounded,
                  ),
                  _buildFeatureCard(
                    'Plant and Aquaculture Records',
                    'Grower profiles, fish batches, plants, and system sets are kept organized for follow-up.',
                    bodySize,
                    isNarrow,
                    Icons.eco_rounded,
                  ),
                  _buildFeatureCard(
                    'Reports',
                    'History and summaries support school, community, and small business reporting needs.',
                    bodySize,
                    isNarrow,
                    Icons.summarize_rounded,
                  ),
                  _buildFeatureCard(
                    'Solar Backup',
                    'Battery and solar status help operators prepare for outages and unstable field power.',
                    bodySize,
                    isNarrow,
                    Icons.solar_power_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhyChoose({
    required bool isNarrow,
    required double titleSize,
    required double bodySize,
  }) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Benefits for Sustainable Food Production',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: AquaponicsColors.greenhouseText,
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildBenefitCard(
                    'Healthier fish and plants',
                    'Keep water conditions closer to the safe range.',
                    bodySize,
                    isNarrow,
                    Icons.eco_rounded,
                  ),
                  _buildBenefitCard(
                    'Fewer losses',
                    'Catch water and power issues before they become costly.',
                    bodySize,
                    isNarrow,
                    Icons.health_and_safety_rounded,
                  ),
                  _buildBenefitCard(
                    'Faster alerts',
                    'See what happened, how serious it is, and what to check next.',
                    bodySize,
                    isNarrow,
                    Icons.speed_rounded,
                  ),
                  _buildBenefitCard(
                    'Less manual work',
                    'Reduce repeated checking and recordkeeping for small operators.',
                    bodySize,
                    isNarrow,
                    Icons.engineering_rounded,
                  ),
                  _buildBenefitCard(
                    'Resilient power',
                    'Solar and battery backup help keep pumps and aeration protected.',
                    bodySize,
                    isNarrow,
                    Icons.battery_charging_full_rounded,
                  ),
                  _buildBenefitCard(
                    'Community-ready',
                    'Useful for fisherfolks, schools, farmers, urban growers, and admins.',
                    bodySize,
                    isNarrow,
                    Icons.groups_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutLytra({
    required double titleSize,
    required double bodySize,
  }) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0f2027),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About the System',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'This capstone system is built for small-scale aquaponics and fishpond operations that need practical monitoring, reliable alerts, and sustainable energy support.',
                style: TextStyle(
                  fontSize: bodySize,
                  color: Colors.white70,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'It brings aquaculture, hydroponics, environmental sensing, and hybrid power into one control center for fisherfolks, community projects, schools, urban gardeners, business owners, and administrators.',
                style: TextStyle(
                  fontSize: bodySize,
                  color: Colors.white70,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 26),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(AboutPage.createRoute());
                },
                child: const Text(
                  'Learn More',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallToAction({required double titleSize}) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0C5B5A),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 54),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ready to Monitor an Aquaponics System with Confidence?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0C5B5A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(InquirePage.createRoute());
                  },
                  child: const Text(
                    'Request Demo',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(ContactPage.createRoute());
                  },
                  child: const Text(
                    'Contact Us',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter({required bool isNarrow, required double bodySize}) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF08141A),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Wrap(
            spacing: 36,
            runSpacing: 24,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: isNarrow ? double.infinity : 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Aquaponics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: bodySize + 5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Smart, sustainable, and technology-driven aquaponics.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: bodySize - 1,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: isNarrow ? double.infinity : 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Links',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: bodySize + 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _footerLink('About Us', () {
                      Navigator.of(context).push(AboutPage.createRoute());
                    }, bodySize),
                    const SizedBox(height: 8),
                    _footerLink('Contact Us', () {
                      Navigator.of(context).push(ContactPage.createRoute());
                    }, bodySize),
                    const SizedBox(height: 8),
                    _footerLink('Login', () {
                      Navigator.of(context).push(
                        LoginPage.createRoute(
                          themeMode: widget.themeMode,
                          onThemeChanged: widget.onThemeChanged,
                        ),
                      );
                    }, bodySize),
                  ],
                ),
              ),
              SizedBox(
                width: isNarrow ? double.infinity : 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: bodySize + 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _footerInfo(
                      Icons.email_outlined,
                      'info@smartaquaponics.com',
                      bodySize,
                    ),
                    const SizedBox(height: 8),
                    _footerInfo(
                      Icons.phone_outlined,
                      '+63 912 345 6789',
                      bodySize,
                    ),
                    const SizedBox(height: 8),
                    _footerInfo(
                      Icons.location_on_outlined,
                      'Bulacan, Philippines',
                      bodySize,
                    ),
                    const SizedBox(height: 8),
                    _footerInfo(
                      Icons.access_time_outlined,
                      'Mon-Fri: 8AM - 5PM',
                      bodySize,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: isNarrow ? double.infinity : 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Social Media',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: bodySize + 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _footerSocialIcon(
                          Icons.facebook,
                          Colors.blueAccent,
                          bodySize,
                        ),
                        _footerSocialIcon(
                          Icons.camera_alt,
                          Colors.pinkAccent,
                          bodySize,
                        ),
                        _footerSocialIcon(
                          Icons.play_circle_fill,
                          Colors.redAccent,
                          bodySize,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                height: 1,
                color: Colors.white.withValues(alpha: 0.14),
              ),
              Text(
                'Copyright 2026 Smart Aquaponics. All rights reserved.',
                style: TextStyle(
                  color: isNarrow ? Colors.white54 : Colors.white70,
                  fontSize: bodySize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeItem(String text, double fontSize) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.insights_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: fontSize, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String label, VoidCallback onTap, double bodySize) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white70,
          fontSize: bodySize,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white30,
        ),
      ),
    );
  }

  Widget _footerInfo(IconData icon, String text, double bodySize) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: bodySize + 2, color: Colors.white60),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white70,
              fontSize: bodySize,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _footerSocialIcon(IconData icon, Color color, double bodySize) {
    return Container(
      width: bodySize + 24,
      height: bodySize + 24,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, color: color, size: bodySize + 4),
    );
  }

  Widget _buildHeroFeatureCards({
    required bool isNarrow,
    required double bodySize,
  }) {
    final cards = [
      (
        icon: Icons.water_drop_rounded,
        text: 'Monitor pH, oxygen, turbidity, and temperature',
      ),
      (
        icon: Icons.solar_power_rounded,
        text: 'Hybrid solar and battery backup',
      ),
      (
        icon: Icons.notifications_active_rounded,
        text: 'Plain-language alerts and reports',
      ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isNarrow ? double.infinity : 520),
      child: Column(
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            _buildHeroFeatureCard(
              cards[index].text,
              bodySize,
              cards[index].icon,
            ),
            if (index != cards.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroFeatureCard(String text, double bodySize, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AquaponicsColors.adminBorder),
        boxShadow: const [
          BoxShadow(
            color: AquaponicsColors.greenhouseShadow,
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AquaponicsColors.mossGreen, size: bodySize + 5),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AquaponicsColors.greenhouseText,
                fontSize: bodySize,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagCard(String text, double bodySize, IconData icon) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x14000000)),
          boxShadow: const [
            BoxShadow(
              color: AquaponicsColors.greenhouseShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AquaponicsColors.mossGreen, size: bodySize + 2),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: AquaponicsColors.greenhouseText,
                  fontSize: bodySize,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(
    String step,
    String text,
    double bodySize,
    bool isNarrow,
  ) {
    return Container(
      width: isNarrow ? double.infinity : 250,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: AquaponicsColors.greenhouseShadow,
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AquaponicsColors.deepTeal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              step,
              style: TextStyle(
                fontSize: bodySize - 1,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: bodySize,
              color: AquaponicsColors.greenhouseText,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    String description,
    double bodySize,
    bool isNarrow,
    IconData icon,
  ) {
    return Container(
      width: isNarrow ? double.infinity : 330,
      constraints: const BoxConstraints(minHeight: 164),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: AquaponicsColors.greenhouseShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AquaponicsColors.deepTeal,
              size: bodySize + 2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: bodySize + 1,
              color: AquaponicsColors.greenhouseText,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: bodySize - 1,
              color: AquaponicsColors.greenhouseSubtext,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitCard(
    String title,
    String description,
    double bodySize,
    bool isNarrow,
    IconData icon,
  ) {
    return Container(
      width: isNarrow ? double.infinity : 340,
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: AquaponicsColors.greenhouseShadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AquaponicsColors.mossGreen,
              size: bodySize + 2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: bodySize,
                    color: AquaponicsColors.greenhouseText,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: bodySize - 1,
                    color: AquaponicsColors.greenhouseSubtext,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagramNode extends StatelessWidget {
  final String label;

  const _DiagramNode({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD2DCE7)),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B2838),
          ),
        ),
      ),
    );
  }
}

class NavItem extends StatelessWidget {
  final String title;
  final double fontSize;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const NavItem({
    super.key,
    required this.title,
    this.fontSize = 16,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (title == 'About Us') {
          Navigator.of(context).push(AboutPage.createRoute());
        } else if (title == 'Contact Us') {
          Navigator.of(context).push(ContactPage.createRoute());
        } else if (title == 'Login') {
          Navigator.of(context).push(
            LoginPage.createRoute(
              themeMode: themeMode,
              onThemeChanged: onThemeChanged,
            ),
          );
        }
      },
      child: Text(
        title,
        style: TextStyle(
          color: AquaponicsColors.greenhouseText,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
