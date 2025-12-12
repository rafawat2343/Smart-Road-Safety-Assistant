// lib/home.dart
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'theme_notifier.dart';
import 'profile.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final List<String> _titles = ["Dashboard", "Detection", "Records", "Profile"];

  // Bounce animation controller
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: 0.88,
      upperBound: 1.0,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  // ----------------------- Loader Dialog -----------------------
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 15),
              Text(
                "Fetching location...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------- Share Location -----------------------
  Future<void> _shareLocation() async {
    _showLoadingDialog();

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission denied")),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double lat = position.latitude;
      double lng = position.longitude;

      String link = "https://www.google.com/maps?q=$lat,$lng";

      Navigator.pop(context);

      await Share.share(
        "📍 My current location:\n$link",
        subject: "My Live Location",
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeNotifier>(context).isDark;

    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(_titles[_selectedIndex]),
          leading: (_selectedIndex == 0)
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  onPressed: () => setState(() => _selectedIndex = 0),
                ),
          actions: [
            if (_selectedIndex == 3) ...[
              IconButton(
                icon: const Icon(Icons.brightness_6),
                onPressed: () {
                  Provider.of<ThemeNotifier>(
                    context,
                    listen: false,
                  ).toggleTheme();
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.red),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
              ),
            ],
          ],
        ),

        body: _buildBody(),

        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          selectedItemColor: Colors.greenAccent,
          unselectedItemColor: isDark ? Colors.white54 : Colors.grey,
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

  // ------------------------------ Body Switcher ------------------------------
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

  // ------------------------------ Dashboard ------------------------------
  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [_headerCard(), const SizedBox(height: 25), _quickActions()],
      ),
    );
  }

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

  // ------------------------------ Quick Buttons ------------------------------
  Widget _quickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _bounceButton(Icons.camera_alt, "Detection", Colors.red, () {
          setState(() => _selectedIndex = 1);
        }),
        _bounceButton(Icons.history, "Records", Colors.blue, () {
          setState(() => _selectedIndex = 2);
        }),
        _bounceButton(
          Icons.location_on,
          "Share Loc",
          Colors.green,
          _shareLocation,
        ),
      ],
    );
  }

  // ----------------------- Bounce Button -----------------------
  Widget _bounceButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTapDown: (_) {
        _bounceController.reverse();
      },
      onTapUp: (_) {
        _bounceController.forward();
        onTap();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
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

  // ------------------------------ Detection ------------------------------
  Widget _buildDetection() {
    const platform = MethodChannel("drive_mind/native");

    Future<void> openNativeActivity() async {
      try {
        await platform.invokeMethod("openNativeActivity");
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
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

  // ------------------------------ Records ------------------------------
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
