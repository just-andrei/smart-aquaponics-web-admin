import 'package:flutter/material.dart';

class InquirePage extends StatefulWidget {
  const InquirePage({super.key});

  @override
  State<InquirePage> createState() => _InquirePageState();

  static Route createRoute() {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const InquirePage(),
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

class _InquirePageState extends State<InquirePage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _companyController = TextEditingController();
  final _locationController = TextEditingController();
  final _farmSizeController = TextEditingController();
  final _messageController = TextEditingController();

  String? _inquiryType;
  String? _budgetRange;
  String _setupLocation = 'Indoor';
  DateTime? _preferredSetupDate;

  bool _showCard = false;

  static const List<String> _inquiryOptions = [
    'Plant Only',
    'Aquaculture Only',
    'Full Aquaponics Setup',
    'Custom System Consultation',
    'IoT Monitoring System',
    'Bulk Order',
  ];

  static const List<String> _budgetOptions = [
    '\u20B110,000-\u20B150,000',
    '\u20B150,000-\u20B1100,000',
    '\u20B1100,000+',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _showCard = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _farmSizeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleBack(BuildContext context) async {
    final didPop = await Navigator.of(context).maybePop();
    if (!didPop && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredSetupDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() {
        _preferredSetupDate = picked;
      });
    }
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
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

  String? _contactValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Contact Number is required.';
    }
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digitsOnly.length < 10) {
      return 'Enter a valid contact number.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inquiry submitted successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 1200).clamp(0.6, 1.0);
    final backFontSize = (16 * scale).clamp(11.0, 16.0);
    final backIconSize = (24 * scale).clamp(16.0, 24.0);
    final brandFontSize = (22 * scale).clamp(14.0, 22.0);
    final sectionTitleFontSize = (22 * scale).clamp(15.0, 22.0);
    final labelFontSize = (16 * scale).clamp(12.0, 16.0);

    return Scaffold(
      body: Stack(
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
          Column(
            children: [
              Container(
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
                      InkWell(
                        onTap: () => _handleBack(context),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_back, color: Colors.white, size: backIconSize),
                            const SizedBox(width: 8),
                            Text(
                              'Back',
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
                        'Inquire with LYTRA',
                        style: TextStyle(
                          fontSize: brandFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmallScreen = constraints.maxWidth < 900;

                    return SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: _showCard ? 1 : 0,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          offset: _showCard ? Offset.zero : const Offset(0, 0.05),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
                              margin: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 20 : 85,
                                vertical: 48,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0f2027).withOpacity(0.55),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1080),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Basic Information',
                                        style: TextStyle(
                                          fontSize: sectionTitleFontSize,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildTextField(
                                        controller: _fullNameController,
                                        label: 'Full Name *',
                                        validator: (value) => _requiredValidator(value, 'Full Name'),
                                        labelFontSize: labelFontSize,
                                      ),
                                      _buildTextField(
                                        controller: _emailController,
                                        label: 'Email Address *',
                                        keyboardType: TextInputType.emailAddress,
                                        validator: _emailValidator,
                                        labelFontSize: labelFontSize,
                                      ),
                                      _buildTextField(
                                        controller: _contactController,
                                        label: 'Contact Number *',
                                        keyboardType: TextInputType.phone,
                                        validator: _contactValidator,
                                        labelFontSize: labelFontSize,
                                      ),
                                      _buildTextField(
                                        controller: _companyController,
                                        label: 'Company Name (optional)',
                                        labelFontSize: labelFontSize,
                                      ),
                                      _buildTextField(
                                        controller: _locationController,
                                        label: 'Location / Address *',
                                        validator: (value) => _requiredValidator(value, 'Location / Address'),
                                        labelFontSize: labelFontSize,
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'Inquiry Type',
                                        style: TextStyle(
                                          fontSize: sectionTitleFontSize,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildDropdown(
                                        label: 'Select Inquiry Type *',
                                        value: _inquiryType,
                                        items: _inquiryOptions,
                                        onChanged: (value) => setState(() => _inquiryType = value),
                                        validator: (value) =>
                                            value == null || value.isEmpty ? 'Inquiry Type is required.' : null,
                                        labelFontSize: labelFontSize,
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'System Requirements',
                                        style: TextStyle(
                                          fontSize: sectionTitleFontSize,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildTextField(
                                        controller: _farmSizeController,
                                        label: 'Estimated Farm Size (sqm)',
                                        keyboardType: TextInputType.number,
                                        labelFontSize: labelFontSize,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Setup Location',
                                        style: TextStyle(
                                          fontSize: labelFontSize,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 4,
                                        children: [
                                          _buildRadioOption('Indoor'),
                                          _buildRadioOption('Outdoor'),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _buildDropdown(
                                        label: 'Budget Range',
                                        value: _budgetRange,
                                        items: _budgetOptions,
                                        onChanged: (value) => setState(() => _budgetRange = value),
                                        labelFontSize: labelFontSize,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Preferred Setup Date',
                                        style: TextStyle(
                                          fontSize: labelFontSize,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: _pickDate,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _preferredSetupDate == null
                                                ? 'Select Date'
                                                : '${_preferredSetupDate!.month}/${_preferredSetupDate!.day}/${_preferredSetupDate!.year}',
                                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        'Additional Details',
                                        style: TextStyle(
                                          fontSize: sectionTitleFontSize,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildTextField(
                                        controller: _messageController,
                                        label: 'Message / Special Request',
                                        maxLines: 5,
                                        labelFontSize: labelFontSize,
                                      ),
                                      const SizedBox(height: 26),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _submit,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(28),
                                            ),
                                          ),
                                          child: const Text(
                                            'Submit Inquiry',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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

  Widget _buildRadioOption(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: _setupLocation,
          onChanged: (selected) {
            if (selected != null) {
              setState(() {
                _setupLocation = selected;
              });
            }
          },
          activeColor: Colors.tealAccent,
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.tealAccent;
            }
            return Colors.white70;
          }),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required double labelFontSize,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: labelFontSize,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          errorStyle: const TextStyle(color: Color(0xFFFFD2D2)),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
    required double labelFontSize,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      validator: validator,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF1F3544),
      iconEnabledColor: Colors.white70,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: labelFontSize,
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        errorStyle: const TextStyle(color: Color(0xFFFFD2D2)),
      ),
      items: items
          .map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            ),
          )
          .toList(),
    );
  }
}
