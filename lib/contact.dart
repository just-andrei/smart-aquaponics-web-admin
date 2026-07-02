import 'package:flutter/material.dart';

import 'about.dart';
import 'login.dart';
import 'public_page_shell.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();

  static Route createRoute() {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const ContactPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );
      },
    );
  }
}

class _ContactPageState extends State<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _navigate(String destination) {
    switch (destination) {
      case 'Home':
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/landing', (route) => false);
        break;
      case 'About Us':
        Navigator.of(context).pushReplacement(AboutPage.createRoute());
        break;
      case 'Contact Us':
        break;
      case 'Login':
        Navigator.of(context).pushReplacement(LoginPage.createRoute());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useSingleColumn = screenWidth < 920;
    final titleSize = screenWidth < 700 ? 29.0 : 34.0;
    final sectionTitleSize = screenWidth < 700 ? 21.0 : 24.0;
    final bodySize = screenWidth < 700 ? 15.0 : 16.0;

    return PublicPageScaffold(
      currentPage: 'Contact Us',
      onNavigate: _navigate,
      maxContentWidth: 1080,
      child: PublicGlassCard(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth < 700 ? 22 : 34,
          vertical: screenWidth < 700 ? 24 : 34,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Us',
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1D2A24),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Text(
                'Reach out for product questions, implementation details, or a walkthrough of the smart aquaponics dashboard.',
                style: TextStyle(
                  fontSize: bodySize,
                  color: const Color(0xFF66746D),
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 28),
            useSingleColumn
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ContactInfoPanel(
                        sectionTitleSize: sectionTitleSize,
                        bodyFontSize: bodySize,
                      ),
                      const SizedBox(height: 24),
                      _ContactFormPanel(
                        formKey: _formKey,
                        fullNameController: _fullNameController,
                        emailController: _emailController,
                        subjectController: _subjectController,
                        messageController: _messageController,
                        sectionTitleSize: sectionTitleSize,
                        bodyFontSize: bodySize,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ContactInfoPanel(
                          sectionTitleSize: sectionTitleSize,
                          bodyFontSize: bodySize,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _ContactFormPanel(
                          formKey: _formKey,
                          fullNameController: _fullNameController,
                          emailController: _emailController,
                          subjectController: _subjectController,
                          messageController: _messageController,
                          sectionTitleSize: sectionTitleSize,
                          bodyFontSize: bodySize,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

class _ContactInfoPanel extends StatelessWidget {
  final double sectionTitleSize;
  final double bodyFontSize;

  const _ContactInfoPanel({
    required this.sectionTitleSize,
    required this.bodyFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: TextStyle(
              fontSize: sectionTitleSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D2A24),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We usually respond during business hours and can help with demos, onboarding, and platform questions.',
            style: TextStyle(
              color: const Color(0xFF66746D),
              fontSize: bodyFontSize,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          const _ContactInfoTile(
            icon: Icons.email_outlined,
            title: 'Email',
            value: 'info@smartaquaponics.com',
          ),
          const SizedBox(height: 14),
          const _ContactInfoTile(
            icon: Icons.phone_outlined,
            title: 'Phone',
            value: '+63 912 345 6789',
          ),
          const SizedBox(height: 14),
          const _ContactInfoTile(
            icon: Icons.location_on_outlined,
            title: 'Location',
            value: 'Bulacan, Philippines',
          ),
          const SizedBox(height: 14),
          const _ContactInfoTile(
            icon: Icons.access_time_outlined,
            title: 'Hours',
            value: 'Mon-Fri: 8AM - 5PM',
          ),
          const SizedBox(height: 28),
          Text(
            'Follow Us',
            style: TextStyle(
              fontSize: sectionTitleSize - 2,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D2A24),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _SocialIcon(icon: Icons.facebook, color: Colors.blueAccent),
              _SocialIcon(icon: Icons.camera_alt, color: Colors.pinkAccent),
              _SocialIcon(
                icon: Icons.play_circle_fill,
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactFormPanel extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController subjectController;
  final TextEditingController messageController;
  final double sectionTitleSize;
  final double bodyFontSize;

  const _ContactFormPanel({
    required this.formKey,
    required this.fullNameController,
    required this.emailController,
    required this.subjectController,
    required this.messageController,
    required this.sectionTitleSize,
    required this.bodyFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send us a Message',
              style: TextStyle(
                fontSize: sectionTitleSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1D2A24),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tell us what you need and we will point you to the right next step.',
              style: TextStyle(
                color: const Color(0xFF66746D),
                fontSize: bodyFontSize,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),
            _PublicFormField(
              hint: 'Full Name',
              controller: fullNameController,
              validator: (value) => _requiredValidator(value, 'Full Name'),
            ),
            const SizedBox(height: 14),
            _PublicFormField(
              hint: 'Email Address',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
            ),
            const SizedBox(height: 14),
            _PublicFormField(
              hint: 'Subject',
              controller: subjectController,
              validator: (value) => _requiredValidator(value, 'Subject'),
            ),
            const SizedBox(height: 14),
            _PublicFormField(
              hint: 'Message',
              controller: messageController,
              maxLines: 5,
              validator: (value) => _requiredValidator(value, 'Message'),
            ),
            const SizedBox(height: 22),
            PublicPageButton(
              label: 'Send Message',
              leading: const Icon(Icons.send_rounded, size: 18),
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Your message has been successfully sent.'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ContactInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2EE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF1E5D5A), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1D2A24),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(color: Color(0xFF66746D), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SocialIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.52)),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _PublicFormField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _PublicFormField({
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF1D2A24),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: publicInputDecoration(hintText: hint),
    );
  }
}

String? _requiredValidator(String? value, String field) {
  if (value == null || value.trim().isEmpty) {
    return '$field is required.';
  }
  return null;
}

String? _emailValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email Address is required.';
  }
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(value.trim())) {
    return 'Enter a valid email address.';
  }
  return null;
}
