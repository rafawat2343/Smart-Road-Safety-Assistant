import 'package:flutter/material.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<String> _titles = ["Dashboard", "Detection", "Records", "Profile"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: _selectedIndex == 3
            ? [
                IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                  onPressed: () {
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

      body: _buildBody(),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF4ADE80),
        unselectedItemColor: Colors.grey.shade500,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_rounded),
            label: "Detect",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: "Records",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: "Profile",
          ),
        ],
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
        return _buildProfile();
      default:
        return _buildDashboard();
    }
  }

  // --- Dashboard ---
  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 24),
          _buildQuickActions(),
          const SizedBox(height: 24),
          _buildStatCards(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFF4ADE80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.shade100,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Welcome to Drive Mind!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Smarter Roads, Safer Drives.",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _quickAction(
          Icons.camera_alt_rounded,
          "Detection",
          const Color(0xFFEF4444),
          1,
        ),
        _quickAction(
          Icons.history_rounded,
          "Records",
          const Color(0xFF2563EB),
          2,
        ),
        _quickAction(
          Icons.location_on_rounded,
          "Share Loc",
          const Color(0xFF4ADE80),
          null,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Location shared via Google Maps!")),
            );
          },
        ),
      ],
    );
  }

  Widget _quickAction(
    IconData icon,
    String label,
    Color color,
    int? navigateIndex, {
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            if (navigateIndex != null) {
              setState(() => _selectedIndex = navigateIndex);
            } else {
              onTap?.call();
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Icon(icon, color: color, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    return Column(
      children: [
        _statCard(
          "Violations Detected Today",
          "3",
          Icons.warning_amber_rounded,
          const Color(0xFFEF4444),
        ),
        const SizedBox(height: 16),
        _statCard(
          "Safe Driving Score",
          "92%",
          Icons.speed_rounded,
          const Color(0xFF4ADE80),
        ),
        const SizedBox(height: 16),
        _statCard(
          "Total Reports Sent",
          "12",
          Icons.route_rounded,
          const Color(0xFF2563EB),
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --- Detection Page ---
  Widget _buildDetection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_rounded,
            size: 80,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(height: 16),
          const Text(
            "Start Detection Mode",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text("Open camera to detect lane or traffic violations."),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text("Start Detection"),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Starting AI Detection (YOLOv8)..."),
                ),
              );
              // TODO: Integrate YOLOv8 model or TensorFlow plugin here
            },
          ),
        ],
      ),
    );
  }

  // --- Records Page ---
  Widget _buildRecords() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
          title: Text("Lane violation detected on 11 Nov, 10:25 AM"),
          subtitle: Text("Captured via Detection Mode"),
        ),
        ListTile(
          leading: Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
          title: Text("Wrong direction driving - 9 Nov, 3:40 PM"),
          subtitle: Text("Shared to database"),
        ),
      ],
    );
  }

  // --- Profile Page ---
  Widget _buildProfile() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.person_rounded, size: 80, color: Color(0xFF2563EB)),
          SizedBox(height: 16),
          Text(
            "User Profile",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text("View or update your profile information."),
        ],
      ),
    );
  }
}
