import 'dart:ui';

import 'package:flutter/material.dart';

import 'aquaponics_colors.dart';

typedef PublicPageNavigationCallback = void Function(String destination);

class PublicPageScaffold extends StatelessWidget {
  final String currentPage;
  final PublicPageNavigationCallback onNavigate;
  final Widget child;
  final double maxContentWidth;
  final bool centerVertically;

  const PublicPageScaffold({
    super.key,
    required this.currentPage,
    required this.onNavigate,
    required this.child,
    this.maxContentWidth = 1080,
    this.centerVertically = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _PublicPageBackground(),
          Column(
            children: [
              PublicTopBar(currentPage: currentPage, onNavigate: onNavigate),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final horizontalPadding = screenWidth < 640
                        ? 20.0
                        : screenWidth < 960
                        ? 28.0
                        : 40.0;
                    final verticalPadding = screenWidth < 640 ? 24.0 : 36.0;
                    final availableHeight =
                        constraints.maxHeight - (verticalPadding * 2);

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        verticalPadding,
                        horizontalPadding,
                        verticalPadding,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: centerVertically
                              ? availableHeight
                                    .clamp(0.0, double.infinity)
                                    .toDouble()
                              : 0.0,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxContentWidth,
                            ),
                            child: Align(
                              alignment: centerVertically
                                  ? Alignment.center
                                  : Alignment.topCenter,
                              child: child,
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
}

class PublicTopBar extends StatelessWidget {
  final String currentPage;
  final PublicPageNavigationCallback onNavigate;

  const PublicTopBar({
    super.key,
    required this.currentPage,
    required this.onNavigate,
  });

  static const List<String> _destinations = [
    'Home',
    'About Us',
    'Contact Us',
    'Login',
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 860;
    final horizontalPadding = screenWidth < 640 ? 20.0 : 40.0;
    final brandFontSize = screenWidth < 860 ? 18.0 : 22.0;
    final navFontSize = screenWidth < 860 ? 14.0 : 16.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        border: const Border(
          bottom: BorderSide(color: AquaponicsColors.adminBorder),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => onNavigate('Home'),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  'Aquaponics',
                  style: TextStyle(
                    fontSize: brandFontSize,
                    fontWeight: FontWeight.w800,
                    color: AquaponicsColors.greenhouseText,
                  ),
                ),
              ),
            ),
            if (isCompact)
              PopupMenuButton<String>(
                tooltip: 'Open navigation menu',
                icon: const Icon(
                  Icons.menu_rounded,
                  color: AquaponicsColors.greenhouseText,
                ),
                onSelected: onNavigate,
                itemBuilder: (context) => _destinations
                    .map(
                      (destination) => PopupMenuItem<String>(
                        value: destination,
                        child: Text(destination),
                      ),
                    )
                    .toList(),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: _destinations
                    .map(
                      (destination) => _TopBarAction(
                        label: destination,
                        selected: destination == currentPage,
                        fontSize: navFontSize,
                        onTap: () => onNavigate(destination),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class PublicGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const PublicGlassCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.46)),
            boxShadow: const [
              BoxShadow(
                color: AquaponicsColors.greenhouseShadow,
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class PublicPageButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool expanded;
  final bool busy;

  const PublicPageButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.expanded = true,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: AquaponicsColors.mossGreen,
        disabledBackgroundColor: AquaponicsColors.mossGreen.withValues(
          alpha: 0.5,
        ),
        disabledForegroundColor: Colors.white70,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      onPressed: onPressed,
      child: busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

InputDecoration publicInputDecoration({
  required String hintText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: AquaponicsColors.greenhouseSubtext,
      fontSize: 15,
    ),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.76),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: AquaponicsColors.greenhouseBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(
        color: AquaponicsColors.mossGreen,
        width: 1.4,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: Color(0xFFC14A4A)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: Color(0xFFC14A4A), width: 1.4),
    ),
  );
}

class _PublicPageBackground extends StatelessWidget {
  const _PublicPageBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF7FBF7).withValues(alpha: 0.82),
                const Color(0xFFEAF3EE).withValues(alpha: 0.50),
                const Color(0xFF123C35).withValues(alpha: 0.72),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBarAction extends StatelessWidget {
  final String label;
  final bool selected;
  final double fontSize;
  final VoidCallback onTap;

  const _TopBarAction({
    required this.label,
    required this.selected,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AquaponicsColors.mossGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AquaponicsColors.greenhouseText,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
