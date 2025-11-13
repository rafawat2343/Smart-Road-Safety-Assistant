import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash.dart'; // <-- New splash screen
import 'carousel.dart';
import 'login.dart';

void main() {
  runApp(const DriveMindApp());
}

class DriveMindApp extends StatelessWidget {
  const DriveMindApp({super.key});

  // ✅ Check whether the user has seen the carousel before
  Future<bool> _hasSeenCarousel() async {
    final prefs = await SharedPreferences.getInstance();
    // ⚠️ Remove this in production (it forces carousel to reappear every run)
    await prefs.clear();

    return prefs.getBool('seen_carousel') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriveMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFFF5252),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF5252)),
      ),

      // Start with SplashPage first
      home: SplashWrapper(checkCarousel: _hasSeenCarousel),
    );
  }
}

class SplashWrapper extends StatefulWidget {
  final Future<bool> Function() checkCarousel;
  const SplashWrapper({super.key, required this.checkCarousel});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Wait 3 seconds for splash animation
    await Future.delayed(const Duration(seconds: 3));

    final hasSeenCarousel = await widget.checkCarousel();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              hasSeenCarousel ? const LoginPage() : const Carousel(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashPage(); // from splash.dart
  }
}
