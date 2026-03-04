import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
    final brandFontSize = (22 * scale).clamp(14.0, 22.0);
    final sectionTitleFontSize = (26 * scale).clamp(16.0, 26.0);
    final bodyFontSize = (18 * scale).clamp(12.0, 18.0);

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

          /// MAIN CONTENT
          Column(
            children: [

              /// NAVBAR / HEADER
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
                      "About LYTRA",
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

              /// RESPONSIVE SCROLLABLE CONTENT
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {

                    bool isSmallScreen = constraints.maxWidth < 900;

                    return SingleChildScrollView(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 50),
                          margin: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 26 : 85,
                            vertical: 60,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0f2027).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 1240, // limit width para di sobrang lawak
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [

                                Text(
                                  "Company Overview",
                                  style: TextStyle(
                                    fontSize: sectionTitleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                SizedBox(height: 20),

                                Text(
                                  "We are Hybrid Power-Driven Aquaponics with IoT Environmental Control System, a technology-focused initiative that develops smart and sustainable aquaponics solutions. Our system is designed to help fisherfolks, small-scale farmers, and communities improve food production despite challenges such as water quality issues, flooding, and limited resources.",
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),

                                SizedBox(height: 20),

                                Text(
                                  "Mission",
                                  style: TextStyle(
                                    fontSize: sectionTitleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                SizedBox(height: 10),

                                Text(
                                  "Our mission is to provide a reliable and efficient aquaponics system that integrates IoT-based monitoring, automation, and hybrid energy to support sustainable agriculture, reduce manual effort, and improve productivity.",
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),

                                SizedBox(height: 20),

                                Text(
                                  "Vision",
                                  style: TextStyle(
                                    fontSize: sectionTitleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                SizedBox(height: 10),

                                Text(
                                  "We envision communities empowered with smart aquaponics systems that ensure food security, environmental sustainability, and resilience against climate-related challenges.",
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),

                                SizedBox(height: 20),

                                Text(
                                  "How Our System Works",
                                  style: TextStyle(
                                    fontSize: sectionTitleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                SizedBox(height: 10),

                                Text(
                                  "Our system combines aquaculture and hydroponics in a closed-loop environment where fish waste supplies nutrients for plants, while plants help filter and clean the water.",
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),

                                SizedBox(height: 10),

                                Text(
                                  "Through IoT technology, the system monitors key parameters such as pH, temperature, dissolved oxygen, turbidity, and humidity in real time. It features automated controls for feeding and environmental regulation to maintain optimal conditions for both fish and plants.",
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),

                                SizedBox(height: 10),

                                Text(
                                  "The system uses hybrid power that combines electricity and solar energy. It continues operating during power interruptions, making the system more reliable and efficient for sustainable food production.",
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),
                                SizedBox(height: 30),

                                Text(
                                  "LYTRA Acronym Meaning",
                                  style: TextStyle(
                                    fontSize: sectionTitleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                SizedBox(height: 12),


                                Text(
                                  "L - Living / Low-Energy / Lifecycle",
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),
                                Text(
                                  "Y - Yield / Year-round",
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),
                                Text(
                                  "T - Technology-driven / Telemetry-based",
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),
                                Text(
                                  "R - Renewable / Regulated / Resilient",
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),
                                Text(
                                  "A - Aquaponics / Automation / Adaptive",
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: Colors.white70,
                                    height: 1.6,
                                  ),
                                ),

                                SizedBox(height: 16),

                                Text(
                                  "The name LYTRA represents our commitment to developing a smart, sustainable, and technology-driven aquaponics system that promotes efficient food production all year round.",
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    color: Colors.white70,
                                    height: 1.6,
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

  /// FADE TRANSITION
  static Route createRoute() {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const AboutPage(),
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
