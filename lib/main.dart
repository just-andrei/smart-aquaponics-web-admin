import 'package:flutter/material.dart';
import 'about.dart';
import 'contact.dart';
import 'inquire.dart';
import 'login.dart';

void main() {
  runApp(const AquaponicsApp());
}

class AquaponicsApp extends StatefulWidget {
  const AquaponicsApp({super.key});

  @override
  State<AquaponicsApp> createState() => _AquaponicsAppState();
}

class _AquaponicsAppState extends State<AquaponicsApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _handleThemeChanged(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LYTRA',
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6D6A)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F6D6A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: LandingPage(
        themeMode: _themeMode,
        onThemeChanged: _handleThemeChanged,
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
    final scale = (screenWidth / 1200).clamp(0.6, 1.0);
    final isNarrow = screenWidth < 900;

    final brandFontSize = (22 * scale).clamp(14.0, 22.0);
    final navFontSize = (16 * scale).clamp(11.0, 16.0);
    final heroTitleFontSize = (42 * scale).clamp(20.0, 42.0);
    final heroSubtitleFontSize = (18 * scale).clamp(12.0, 18.0);
    final buttonFontSize = (16 * scale).clamp(11.0, 16.0);
    final buttonWidth = (190 * scale).clamp(140.0, 190.0);
    final challengeTitleFontSize = (30 * scale).clamp(18.0, 30.0);
    final challengeItemFontSize = (18 * scale).clamp(12.0, 18.0);
    final sectionTitleSize = (32 * scale).clamp(18.0, 32.0);
    final sectionBodySize = (17 * scale).clamp(12.0, 17.0);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    SizedBox(
                      height: constraints.maxHeight,
                      child: Stack(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('image/aquaponics.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Container(
                            color: Colors.black.withOpacity(0.4),
                          ),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 55),
                              margin: const EdgeInsets.symmetric(horizontal: 40),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0f2027).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Growing a Smarter, Greener Future.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: heroTitleFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    'Powered by hybrid energy and intelligent environmental control.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: heroSubtitleFontSize,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: buttonWidth,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
                                            backgroundColor: Colors.teal,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.of(context).push(InquirePage.createRoute());
                                          },
                                          child: Text(
                                            'Inquire',
                                            style: TextStyle(fontSize: buttonFontSize),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      SizedBox(
                                        width: buttonWidth,
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
                                            side: const BorderSide(color: Colors.white),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                          ),
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Downloading App...')),
                                            );
                                          },
                                          child: Text(
                                            'Download App',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: buttonFontSize,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
                        offset: _showChallenges ? Offset.zero : const Offset(0, 0.06),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                          color: const Color(0xFF0f2027),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 900),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Challenges in Traditional Aquaponics',
                                    style: TextStyle(
                                      fontSize: challengeTitleFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Text(
                                    '- High energy consumption',
                                    style: TextStyle(fontSize: challengeItemFontSize, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    '- Manual monitoring of water quality',
                                    style: TextStyle(fontSize: challengeItemFontSize, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    '- Power outage risks',
                                    style: TextStyle(fontSize: challengeItemFontSize, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    '- Inconsistent plant and fish growth',
                                    style: TextStyle(fontSize: challengeItemFontSize, color: Colors.white70),
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
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0f2027).withOpacity(0.92),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'image/logo.png',
                              height: (36 * scale).clamp(24.0, 36.0),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'LYTRA',
                              style: TextStyle(
                                fontSize: brandFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
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
                'Our Smart Hybrid Solution',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0f2027),
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildTagCard('Hybrid Power System (Solar + Grid + Battery Backup)', bodySize, Icons.battery_charging_full_rounded),
                  _buildTagCard('IoT-enabled real-time monitoring', bodySize, Icons.sensors_rounded),
                  _buildTagCard('Automated environmental control', bodySize, Icons.tune_rounded),
                  _buildTagCard('Remote access via mobile', bodySize, Icons.devices_rounded),
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
                            child: Icon(Icons.arrow_downward, color: Color(0xFF3F4A5A)),
                          ),
                          const _DiagramNode(label: 'IoT Controller'),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Icon(Icons.arrow_downward, color: Color(0xFF3F4A5A)),
                          ),
                          const _DiagramNode(label: 'Automation'),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Icon(Icons.arrow_downward, color: Color(0xFF3F4A5A)),
                          ),
                          const _DiagramNode(label: 'Dashboard'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: _DiagramNode(label: 'Sensors')),
                          Icon(Icons.arrow_forward, color: Color(0xFF3F4A5A)),
                          Expanded(child: _DiagramNode(label: 'IoT Controller')),
                          Icon(Icons.arrow_forward, color: Color(0xFF3F4A5A)),
                          Expanded(child: _DiagramNode(label: 'Automation')),
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
                'How It Works',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0f2027),
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildStepCard('Step 1', 'Sensors collect environmental data', bodySize, isNarrow),
                  _buildStepCard('Step 2', 'IoT controller processes information', bodySize, isNarrow),
                  _buildStepCard('Step 3', 'System automatically adjusts components', bodySize, isNarrow),
                  _buildStepCard('Step 4', 'User monitors remotely through dashboard', bodySize, isNarrow),
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
                'KEY FEATURES',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0f2027),
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildFeatureCard('Hybrid energy integration', bodySize, isNarrow, Icons.bolt_rounded),
                  _buildFeatureCard('Real-time monitoring', bodySize, isNarrow, Icons.monitor_heart_rounded),
                  _buildFeatureCard('Automated pH and temperature control', bodySize, isNarrow, Icons.thermostat_rounded),
                  _buildFeatureCard('Smart alerts and notifications', bodySize, isNarrow, Icons.notifications_active_rounded),
                  _buildFeatureCard('Backup power protection', bodySize, isNarrow, Icons.security_rounded),
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
                'Why Choose Our System',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0f2027),
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildBenefitCard('Lower electricity costs', bodySize, isNarrow, Icons.savings_rounded),
                  _buildBenefitCard('Higher crop yield', bodySize, isNarrow, Icons.eco_rounded),
                  _buildBenefitCard('Reduced manual labor', bodySize, isNarrow, Icons.engineering_rounded),
                  _buildBenefitCard('More stable ecosystem', bodySize, isNarrow, Icons.water_drop_rounded),
                  _buildBenefitCard('Sustainable farming solution', bodySize, isNarrow, Icons.energy_savings_leaf_rounded),
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
                'About LYTRA',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'LYTRA (Living, Yield, Technology-driven, Renewable Aquaponics) is a Hybrid Power-Driven Aquaponics System with IoT Environmental Control designed to provide smart and sustainable food production solutions.',
                style: TextStyle(
                  fontSize: bodySize,
                  color: Colors.white70,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Our system integrates aquaculture and hydroponics in a closed-loop environment while using IoT-based monitoring and automation to maintain optimal conditions for fish and plants. Powered by a hybrid combination of electricity and solar energy, LYTRA ensures reliable, efficient, and climate-resilient agricultural production for communities, fisherfolks, and small-scale farmers.',
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
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(AboutPage.createRoute());
                },
                child: const Text(
                  'About Us',
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
              'Ready to Build a Smart Aquaponics System?',
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
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(InquirePage.createRoute());
                  },
                  child: const Text(
                    'Inquire',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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

  Widget _buildFooter({
    required bool isNarrow,
    required double bodySize,
  }) {
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
                      'LYTRA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: bodySize + 5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Living, Yield, Technology-driven, Renewable Aquaponics',
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
                    _footerInfo(Icons.email_outlined, 'LYTRAquponics@gmail.com', bodySize),
                    const SizedBox(height: 8),
                    _footerInfo(Icons.phone_outlined, '+63 912 345 6789', bodySize),
                    const SizedBox(height: 8),
                    _footerInfo(Icons.location_on_outlined, 'Bulacan, Philippines', bodySize),
                    const SizedBox(height: 8),
                    _footerInfo(Icons.access_time_outlined, 'Mon-Fri: 8AM - 5PM', bodySize),
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
                        _footerSocialIcon(Icons.facebook, Colors.blueAccent, bodySize),
                        _footerSocialIcon(Icons.camera_alt, Colors.pinkAccent, bodySize),
                        _footerSocialIcon(Icons.play_circle_fill, Colors.redAccent, bodySize),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                height: 1,
                color: Colors.white.withOpacity(0.14),
              ),
              Text(
                'Copyright 2026 LYTRA. All rights reserved.',
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
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, color: color, size: bodySize + 4),
    );
  }

  Widget _buildTagCard(String text, double bodySize, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE4EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF0F6D6A), size: bodySize + 2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: const Color(0xFF1B2838),
                fontSize: bodySize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(String step, String text, double bodySize, bool isNarrow) {
    return Container(
      width: isNarrow ? double.infinity : 250,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE4EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F6D6A),
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
              color: const Color(0xFF2F3E50),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String text, double bodySize, bool isNarrow, IconData icon) {
    return Container(
      width: isNarrow ? double.infinity : 330,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE4EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0F6D6A), size: bodySize + 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: bodySize,
                color: const Color(0xFF1B2838),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitCard(String text, double bodySize, bool isNarrow, IconData icon) {
    return Container(
      width: isNarrow ? double.infinity : 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF7F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCFE5E2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0F6D6A), size: bodySize + 2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: bodySize,
                color: const Color(0xFF16413E),
                fontWeight: FontWeight.w600,
              ),
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
          color: Colors.white,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
