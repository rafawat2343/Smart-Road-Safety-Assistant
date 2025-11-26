import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _usernameController = TextEditingController();
  final _answerController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 1;

  String? savedQuestion;
  String? savedAnswer;
  String? userEmail;
  String? userId;

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _loading = false;

  // ----------------------------------------------------------
  // Step 1: Check username and load stored security question
  // ----------------------------------------------------------
  Future<void> _checkUsername() async {
    setState(() => _loading = true);

    try {
      var snap = await FirebaseFirestore.instance
          .collection("Users")
          .where("username", isEqualTo: _usernameController.text.trim())
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Username not found!"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _loading = false);
        return;
      }

      var data = snap.docs.first;
      userId = data.id;
      savedQuestion = data["securityQuestion"];
      savedAnswer = data["securityAnswer"];
      userEmail = data["email"]; // needed to update password in auth

      setState(() {
        _step = 2;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ----------------------------------------------------------
  // Step 3: Update new password in Firebase Auth + Firestore
  // ----------------------------------------------------------
  Future<void> _updatePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Login user silently to update password
      UserCredential
      tempLogin = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: userEmail!,
        password:
            savedAnswer!, // using security answer as temp login is NOT recommended, but you requested fully offline reset
      );

      await tempLogin.user!.updatePassword(_newPasswordController.text.trim());

      // Also update password in Firestore (if you store it)
      await FirebaseFirestore.instance.collection("Users").doc(userId).update({
        "password": _newPasswordController.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => _loading = false);
  }

  // ----------------------------------------------------------
  // BUILD UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC1B6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _buildStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Top header
  Widget _buildHeader() {
    return ClipPath(
      clipper: BottomWaveClipper(),
      child: Container(
        height: 330,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF8A80), Color(0xFFFF5252)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock_reset_rounded, color: Colors.white, size: 80),
            SizedBox(height: 10),
            Text(
              "Forgot Password",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              "Recover your account securely",
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  // Step content switcher
  Widget _buildStepContent() {
    if (_step == 1) return _buildUsernameStep();
    if (_step == 2) return _buildSecurityStep();
    return _buildNewPasswordStep();
  }

  // Step 1: Username
  Widget _buildUsernameStep() {
    return Column(
      key: const ValueKey(1),
      children: [
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: "Enter Username",
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        _loading
            ? const CircularProgressIndicator()
            : _button("Continue", _checkUsername),
      ],
    );
  }

  // Step 2: Security question (fixed)
  Widget _buildSecurityStep() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Your Security Question",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),

        // Fixed question box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(savedQuestion ?? "Loading..."),
        ),

        const SizedBox(height: 20),

        TextField(
          controller: _answerController,
          decoration: const InputDecoration(
            labelText: "Enter your answer",
            prefixIcon: Icon(Icons.edit),
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 20),

        _loading
            ? const CircularProgressIndicator()
            : _button("Verify", () {
                if (_answerController.text.trim().toLowerCase() ==
                    savedAnswer!.toLowerCase()) {
                  setState(() => _step = 3);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Incorrect answer!"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }),
      ],
    );
  }

  // Step 3: Set new password (NO EMAIL)
  Widget _buildNewPasswordStep() {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPass,
          decoration: InputDecoration(
            labelText: "New Password",
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPass ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscureNewPass = !_obscureNewPass),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPass,
          decoration: InputDecoration(
            labelText: "Confirm Password",
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPass ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirmPass = !_obscureConfirmPass),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        _loading
            ? const CircularProgressIndicator()
            : _button("Update Password", _updatePassword),
      ],
    );
  }

  Widget _button(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5252),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// Wave header (unchanged)
class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 80);
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 60);
    var secondControlPoint = Offset(3 * size.width / 4, size.height - 120);
    var secondEndPoint = Offset(size.width, size.height - 50);
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
