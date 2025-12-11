// lib/home.dart
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<String> _titles = ["Dashboard", "Detection", "Records", "Profile"];

  // 3D tilt animation controllers
  double tiltX = 0;
  double tiltY = 0;

  void _startTiltAnimation() {
    setState(() {
      tiltX = 0.15;
      tiltY = -0.15;
    });

    Future.delayed(const Duration(milliseconds: 120), () {
      setState(() {
        tiltX = 0;
        tiltY = 0;
      });
    });
  }

  // Share Location (Launch Google Maps)
  Future<void> _shareLocation() async {
    const lat = 23.8103; // Example—replace with real GPS later
    const lng = 90.4125;

    final url = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot open maps")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.white,
          title: Text(
            _titles[_selectedIndex],
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: (_selectedIndex == 0)
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.black,
                  ),
                  onPressed: () => setState(() => _selectedIndex = 0),
                ),
          actions: _selectedIndex == 3
              ? [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                  ),
                ]
              : null,
        ),

        // Body
        body: _buildBody(),

        // Bottom Navigation Bar
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Home"),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: "Detect",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: "Records",
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildDetection();
      case 2:
        return _buildRecords();
      case 3:
        return const ProfilePage();
      default:
        return _buildDashboard();
    }
  }

  // ---------------------- DASHBOARD ----------------------
  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [_headerCard(), const SizedBox(height: 25), _quickActions()],
      ),
    );
  }

  // Header
  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.redAccent, Colors.greenAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.greenAccent, blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome to Drive Mind!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "Smarter Roads, Safer Drives.",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Animated Quick Action Buttons
  Widget _quickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _tiltButton(Icons.camera_alt, "Detection", Colors.red, () {
          setState(() => _selectedIndex = 1);
        }),
        _tiltButton(Icons.history, "Records", Colors.blue, () {
          setState(() => _selectedIndex = 2);
        }),
        _tiltButton(Icons.location_on, "Share Loc", Colors.green, () {
          _shareLocation();
        }),
      ],
    );
  }

  // 3D Tilt Effect Button
  Widget _tiltButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTapDown: (_) => _startTiltAnimation(),
      onTapUp: (_) => onTap(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateX(tiltX)
          ..rotateY(tiltY),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(3, 5),
                  ),
                ],
              ),
              child: Icon(icon, size: 35, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------- DETECTION ----------------------
  Widget _buildDetection() {
    const platform = MethodChannel("drive_mind/native");

    Future<void> openNativeActivity() async {
      try {
        await platform.invokeMethod("openNativeActivity");
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error opening camera: $e")));
      }
    }

    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text("Start Detection"),
        onPressed: openNativeActivity,
      ),
    );
  }

  // ---------------------- RECORDS ----------------------
  Widget _buildRecords() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: Icon(Icons.warning, color: Colors.red),
          title: Text("Lane violation detected on 11 Nov, 10:25 AM"),
        ),
        ListTile(
          leading: Icon(Icons.warning, color: Colors.red),
          title: Text("Wrong direction driving - 9 Nov, 3:40 PM"),
        ),
      ],
    );
  }
}
