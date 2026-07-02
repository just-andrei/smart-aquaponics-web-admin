import 'package:flutter/material.dart';

import 'contact.dart';
import 'login.dart';
import 'public_page_shell.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  void _navigate(BuildContext context, String destination) {
    switch (destination) {
      case 'Home':
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/landing', (route) => false);
        break;
      case 'About Us':
        break;
      case 'Contact Us':
        Navigator.of(context).pushReplacement(ContactPage.createRoute());
        break;
      case 'Login':
        Navigator.of(context).pushReplacement(LoginPage.createRoute());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 700;
    final headingSize = isCompact ? 28.0 : 34.0;
    final sectionTitleSize = isCompact ? 21.0 : 24.0;
    final bodySize = isCompact ? 15.0 : 17.0;

    return PublicPageScaffold(
      currentPage: 'About Us',
      onNavigate: (destination) => _navigate(context, destination),
      maxContentWidth: 980,
      child: PublicGlassCard(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 22 : 36,
          vertical: isCompact ? 24 : 34,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About Us',
              style: TextStyle(
                fontSize: headingSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1D2A24),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Text(
                'Learn how the system combines aquaculture, hydroponics, IoT monitoring, and hybrid power into one practical control center.',
                style: TextStyle(
                  fontSize: bodySize,
                  color: const Color(0xFF66746D),
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 28),
            _AboutSection(
              title: 'Company Overview',
              body:
                  'We are Hybrid Power-Driven Aquaponics with IoT Environmental Control System, a technology-focused initiative that develops smart and sustainable aquaponics solutions. Our system is designed to help fisherfolks, small-scale farmers, and communities improve food production despite challenges such as water quality issues, flooding, and limited resources.',
              titleSize: sectionTitleSize,
              bodySize: bodySize,
            ),
            _AboutSection(
              title: 'Mission',
              body:
                  'Our mission is to provide a reliable and efficient aquaponics system that integrates IoT-based monitoring, automation, and hybrid energy to support sustainable agriculture, reduce manual effort, and improve productivity.',
              titleSize: sectionTitleSize,
              bodySize: bodySize,
            ),
            _AboutSection(
              title: 'Vision',
              body:
                  'We envision communities empowered with smart aquaponics systems that ensure food security, environmental sustainability, and resilience against climate-related challenges.',
              titleSize: sectionTitleSize,
              bodySize: bodySize,
            ),
            _AboutSection(
              title: 'How Our System Works',
              body:
                  'Our system combines aquaculture and hydroponics in a closed-loop environment where fish waste supplies nutrients for plants, while plants help filter and clean the water.\n\nThrough IoT technology, the system monitors key parameters such as pH, temperature, dissolved oxygen, turbidity, and humidity in real time. It features automated controls for feeding and environmental regulation to maintain optimal conditions for both fish and plants.\n\nThe system uses hybrid power that combines electricity and solar energy. It continues operating during power interruptions, making the system more reliable and efficient for sustainable food production.',
              titleSize: sectionTitleSize,
              bodySize: bodySize,
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
              ),
              child: Text(
                'The Smart Aquaponics system reflects our commitment to developing a smart, sustainable, and technology-driven aquaponics solution that promotes efficient food production all year round.',
                style: TextStyle(
                  fontSize: bodySize,
                  color: const Color(0xFF1D2A24),
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Route createRoute() {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const AboutPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );
      },
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String title;
  final String body;
  final double titleSize;
  final double bodySize;

  const _AboutSection({
    required this.title,
    required this.body,
    required this.titleSize,
    required this.bodySize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D2A24),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontSize: bodySize,
              color: const Color(0xFF44524C),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
