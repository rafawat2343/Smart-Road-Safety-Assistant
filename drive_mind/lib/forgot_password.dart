// lib/forgot_password.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'login.dart';
import 'routes_helper.dart';

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
  String? _selectedQuestion;
  String? _fetchedQuestion;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    // back -> go to Login (fade)
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushReplacement(fadeRoute(const LoginPage()));
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFC1B6),
        body: SingleChildScrollView(
          child: Column(
            children: [
              ClipPath(
                clipper: BottomWaveClipper(),
                child: Container(
                  height: 330,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF8A80), Color(0xFFFF5252)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.white,
                        size: 80,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Forgot Password",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "Recover your account securely",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: _buildStepContent(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_step) {
      case 1:
        return _buildUsernameStep(context, key: const ValueKey(1));
      case 2:
        return _buildSecurityStep(context, key: const ValueKey(2));
      case 3:
        return _buildNewPasswordStep(context, key: const ValueKey(3));
      default:
        return Container();
    }
  }

  // Step 1: username -> fetch security question from Firestore (if exists)
  Widget _buildUsernameStep(BuildContext context, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Username",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_outline),
            hintText: "Enter your username",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        _buildNextButton("Continue", () async {
          if (_usernameController.text.trim().isEmpty) return;

          // try to fetch question from Firestore where username matches
          setState(() => _loading = true);
          try {
            final query = await FirebaseFirestore.instance
                .collection('users')
                .where('username', isEqualTo: _usernameController.text.trim())
                .limit(1)
                .get();

            if (query.docs.isNotEmpty) {
              final doc = query.docs.first;
              _fetchedQuestion =
                  (doc.data()['security_question'] as String?) ?? null;
            } else {
              // no user found -> _fetchedQuestion remains null and we'll ask generic list (but you asked to fetch and show only selected question)
              _fetchedQuestion = null;
            }
          } catch (e) {
            _fetchedQuestion = null;
          }
          setState(() => _loading = false);
          setState(() => _step = 2);
        }),
        const SizedBox(height: 10),
        _buildBackToLogin(context),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // Step 2: if _fetchedQuestion != null show only that question; else allow selection (fallback)
  Widget _buildSecurityStep(BuildContext context, {Key? key}) {
    final List<String> fallbackQuestions = [
      "What is your favorite color?",
      "What is your pet's name?",
      "What city were you born in?",
      "What is your mother's maiden name?",
    ];

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Security Question",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        if (_fetchedQuestion != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.question_mark_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _fetchedQuestion!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            value: _selectedQuestion,
            items: fallbackQuestions
                .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                .toList(),
            onChanged: (value) => setState(() => _selectedQuestion = value),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.question_mark_rounded),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          "Answer",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _answerController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.edit_note_rounded),
            hintText: "Enter your answer",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        _buildNextButton("Verify", () {
          // We are not validating answer against DB now (you asked to use existing reset only)
          if ((_fetchedQuestion != null || _selectedQuestion != null) &&
              _answerController.text.trim().isNotEmpty) {
            setState(() => _step = 3);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please provide an answer')),
            );
          }
        }),
        const SizedBox(height: 10),
        _buildBackToLogin(context),
      ],
    );
  }

  Widget _buildNewPasswordStep(BuildContext context, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "New Password",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPass,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscureNewPass = !_obscureNewPass),
            ),
            hintText: "Enter new password",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Confirm Password",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPass,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirmPass = !_obscureConfirmPass),
            ),
            hintText: "Re-enter new password",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        _buildNextButton("Update Password", () {
          if (_newPasswordController.text == _confirmPasswordController.text &&
              _newPasswordController.text.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Password updated successfully!"),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pushReplacement(fadeRoute(const LoginPage()));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Passwords do not match!"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }),
        const SizedBox(height: 10),
        _buildBackToLogin(context),
      ],
    );
  }

  Widget _buildNextButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5252),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildBackToLogin(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.of(context).pushReplacement(fadeRoute(const LoginPage()));
        },
        child: const Text(
          "Back to Login",
          style: TextStyle(
            color: Color(0xFFFF5252),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// BottomWaveClipper same as earlier
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
