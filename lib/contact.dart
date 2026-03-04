import 'package:flutter/material.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();

  /// FADE TRANSITION
  static Route createRoute() {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const ContactPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
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

  Future<void> _handleBack(BuildContext context) async {
    final didPop = await Navigator.of(context).maybePop();
    if (!didPop && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 1200).clamp(0.6, 1.0);
    final backFontSize = (16 * scale).clamp(11.0, 16.0);
    final backIconSize = (24 * scale).clamp(16.0, 24.0);
    final headerFontSize = (22 * scale).clamp(14.0, 22.0);
    final sectionTitleSize = (26 * scale).clamp(16.0, 26.0);
    final followTitleSize = (20 * scale).clamp(14.0, 20.0);
    final bodyFontSize = (16 * scale).clamp(11.0, 16.0);
    final buttonFontSize = (16 * scale).clamp(11.0, 16.0);

    return Scaffold(
      body: Stack(
        children: [
          /// BACKGROUND IMAGE
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('image/aquaponics.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          /// DARK OVERLAY
          Container(
            color: Colors.black.withOpacity(0.4),
          ),

          Column(
            children: [
              /// NAVBAR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
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
                      onTap: () => _handleBack(context),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white, size: backIconSize),
                          const SizedBox(width: 8),
                          Text(
                            "Back",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: backFontSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "Contact Us",
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

              /// CONTENT
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmallScreen = constraints.maxWidth < 900;

                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                            margin: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 26 : 105,
                              vertical: 0,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0f2027).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: isSmallScreen
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _contactInfo(
                                        sectionTitleSize: sectionTitleSize,
                                        followTitleSize: followTitleSize,
                                        bodyFontSize: bodyFontSize,
                                      ),
                                      const SizedBox(height: 60),
                                      _contactForm(
                                        context: context,
                                        sectionTitleSize: sectionTitleSize,
                                        bodyFontSize: bodyFontSize,
                                        buttonFontSize: buttonFontSize,
                                      ),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _contactInfo(
                                          sectionTitleSize: sectionTitleSize,
                                          followTitleSize: followTitleSize,
                                          bodyFontSize: bodyFontSize,
                                        ),
                                      ),
                                      const SizedBox(width: 40),
                                      Expanded(
                                        child: _contactForm(
                                          context: context,
                                          sectionTitleSize: sectionTitleSize,
                                          bodyFontSize: bodyFontSize,
                                          buttonFontSize: buttonFontSize,
                                        ),
                                      ),
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
    );
  }

  static Widget _contactInfo({
    required double sectionTitleSize,
    required double followTitleSize,
    required double bodyFontSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Contact Information",
          style: TextStyle(
            fontSize: sectionTitleSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            const Icon(Icons.email, color: Colors.tealAccent),
            const SizedBox(width: 10),
            Text(
              "LYTRAquponics@gmail.com",
              style: TextStyle(color: Colors.white70, fontSize: bodyFontSize),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            const Icon(Icons.phone, color: Colors.tealAccent),
            const SizedBox(width: 10),
            Text(
              "+63 912 345 6789",
              style: TextStyle(color: Colors.white70, fontSize: bodyFontSize),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.tealAccent),
            const SizedBox(width: 10),
            Text(
              "Bulacan, Philippines",
              style: TextStyle(color: Colors.white70, fontSize: bodyFontSize),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            const Icon(Icons.access_time, color: Colors.tealAccent),
            const SizedBox(width: 10),
            Text(
              "Mon-Fri: 8AM - 5PM",
              style: TextStyle(color: Colors.white70, fontSize: bodyFontSize),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Text(
          "Follow Us",
          style: TextStyle(
            fontSize: followTitleSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _socialIcon(Icons.facebook, Colors.blueAccent, bodyFontSize),
            _socialIcon(Icons.camera_alt, Colors.pinkAccent, bodyFontSize),
            _socialIcon(Icons.play_circle_fill, Colors.redAccent, bodyFontSize),
          ],
        ),
      ],
    );
  }

  static Widget _socialIcon(IconData icon, Color color, double fontSize) {
    return Container(
      width: fontSize + 24,
      height: fontSize + 24,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _contactForm({
    required BuildContext context,
    required double sectionTitleSize,
    required double bodyFontSize,
    required double buttonFontSize,
  }) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Send us a Message",
            style: TextStyle(
              fontSize: sectionTitleSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 25),
          _buildTextField(
            "Full Name",
            controller: _fullNameController,
            fontSize: bodyFontSize,
            validator: (value) => _requiredValidator(value, "Full Name"),
          ),
          const SizedBox(height: 15),
          _buildTextField(
            "Email Address",
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            fontSize: bodyFontSize,
            validator: _emailValidator,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            "Subject",
            controller: _subjectController,
            fontSize: bodyFontSize,
            validator: (value) => _requiredValidator(value, "Subject"),
          ),
          const SizedBox(height: 15),
          _buildTextField(
            "Message",
            controller: _messageController,
            maxLines: 4,
            fontSize: bodyFontSize,
            validator: (value) => _requiredValidator(value, "Message"),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              if (!_formKey.currentState!.validate()) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Your message has been successfully sent."),
                ),
              );
            },
            child: Text(
              "Send Message",
              style: TextStyle(color: Colors.black, fontSize: buttonFontSize),
            ),
          ),
        ],
      ),
    );
  }

  String? _requiredValidator(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return "$field is required.";
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Email Address is required.";
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return "Enter a valid email address.";
    }
    return null;
  }

  static Widget _buildTextField(
    String hint, {
    required TextEditingController controller,
    int maxLines = 1,
    required double fontSize,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
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
        errorStyle: TextStyle(color: Colors.red.shade200, fontSize: fontSize - 2),
      ),
    );
  }
}
