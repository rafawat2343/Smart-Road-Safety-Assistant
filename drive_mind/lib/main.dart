import 'package:drive_mind/home.dart';
import 'package:drive_mind/session_manager.dart';
import 'package:drive_mind/theme_notifier.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash.dart';
import 'carousel.dart';
import 'login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAuth.instance.setLanguageCode('en');

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const DriveMindApp(),
    ),
  );
}

class DriveMindApp extends StatelessWidget {
  const DriveMindApp({super.key});

  Future<bool> _hasSeenCarousel() async {
    final prefs = await SharedPreferences.getInstance();
    // ⚠️ YOU SHOULD REMOVE THIS IN PRODUCTION — forces carousel every time
    await prefs.clear();
    return prefs.getBool('seen_carousel') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      title: 'DriveMind',
      debugShowCheckedModeBanner: false,

      themeMode: themeNotifier.isDark ? ThemeMode.dark : ThemeMode.light,

      // LIGHT THEME
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFFF5252),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // DARK THEME
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E0E0E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

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
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    User? user = FirebaseAuth.instance.currentUser;
    bool hasSeenCarousel = await widget.checkCarousel();

    // 🚀 FIRST TIME USER → SHOW CAROUSEL
    if (!hasSeenCarousel) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Carousel()),
      );
      return;
    }

    // ❌ NOT LOGGED IN → LOGIN PAGE
    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    // ✔ USER LOGGED IN → HOME PAGE
    SessionController().userId = user.uid;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SplashPage();
  }
}
