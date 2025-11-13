import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

class Carousel extends StatefulWidget {
  const Carousel({super.key});

  @override
  State<Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<Carousel> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _page = 0;

  late AnimationController _buttonController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  final List<Map<String, String>> slides = [
    {"title": "Welcome", "subtitle": "Smarter Roads, Safer Drives."},
    {
      "title": "Real-time Alerts",
      "subtitle": "Get alerts about hazards and traffic.",
    },
    {
      "title": "Track Your Driving",
      "subtitle": "Monitor your trips and improve safety.",
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_carousel', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  void initState() {
    super.initState();

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeInOut,
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );

    _buttonController.value = 1.0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _buttonController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = slides.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFC1B6),
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Top Curved Header ----------
            ClipPath(
              clipper: BottomWaveClipper(),
              child: Container(
                height:
                    MediaQuery.of(context).size.height * 0.6, // slightly taller
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF8A80), Color(0xFFFF5252)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ✅ Bigger logo
                      SizedBox(
                        width:
                            MediaQuery.of(context).size.width *
                            0.65, // adjust ratio for fit
                        height:
                            MediaQuery.of(context).size.width *
                            0.65, // keep square shape
                        child: Image.asset(
                          'lib/assets/Logo.png',
                          fit: BoxFit.cover, // fills the box fully
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        "Your journey starts smart",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ---------- Carousel Slides ----------
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide["title"] ?? "",
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide["subtitle"] ?? "",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ---------- Page Controls ----------
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20,
              ),
              child: Row(
                children: [
                  // Skip button
                  InkWell(
                    onTap: () async {
                      Feedback.forTap(context);
                      await Future.delayed(const Duration(milliseconds: 50));
                      _completeOnboarding();
                    },
                    borderRadius: BorderRadius.circular(8),
                    splashColor: Colors.red.withOpacity(0.2),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Text(
                        "Skip",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Page dots
                  Row(
                    children: List.generate(total, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _page == i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _page == i
                              ? const Color(0xFFFF5252)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),

                  const Spacer(),

                  // Next / Let's Drive button
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      double glow = (_page == total - 1)
                          ? _glowAnimation.value * 15
                          : 0;
                      return Container(
                        decoration: BoxDecoration(
                          boxShadow: _page == total - 1
                              ? [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.5),
                                    blurRadius: glow,
                                    spreadRadius: glow / 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5252),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              elevation: 3,
                            ),
                            onPressed: () async {
                              await _buttonController.reverse();
                              await _buttonController.forward();

                              if (_page == total - 1) {
                                _completeOnboarding();
                              } else {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.ease,
                                );
                              }
                            },
                            child: Text(
                              _page == total - 1 ? "Let's Drive" : "Next",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Custom Wave Shape ----------
class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 90);
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 70);
    var secondControlPoint = Offset(3 * size.width / 4, size.height - 140);
    var secondEndPoint = Offset(size.width, size.height - 60);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
