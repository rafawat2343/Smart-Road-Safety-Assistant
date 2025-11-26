import 'package:drive_mind/session_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _securityAnswerController = TextEditingController();

  String? _selectedSecurityQuestion;
  bool _obscurePassword = true;

  final List<String> _securityQuestions = [
    "What is your pet’s name?",
    "What is your mother’s maiden name?",
    "What was your first school?",
    "What city were you born in?",
    "What is your favorite color?",
  ];

  // ---------- Validators ----------
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidUsername(String username) {
    final usernameRegex = RegExp(r'^[A-Za-z][A-Za-z0-9._]*$');
    return usernameRegex.hasMatch(username);
  }

  bool _isValidFullName(String name) {
    final nameRegex = RegExp(r'^[A-Za-z ]+$');
    return nameRegex.hasMatch(name);
  }

  bool _isValidPassword(String password) {
    final passwordRegex =
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z\d]{8,24}$');
    return passwordRegex.hasMatch(password);
  }

  Future <void> signUpToFirebase() async{
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ).then((value) {
        SessionController().userId = value.user!.uid.toString();
        //getting user info using uid that has been created in firebase auth with email and password
        String uid = value.user!.uid;

        //Save user data to Firestore
         FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'username': _usernameController.text.trim(),
          'full_name': _fullnameController.text.trim(),
          'email': _emailController.text.trim(),
          'security_question': _selectedSecurityQuestion,
          'security_answer': _securityAnswerController.text.trim(),
          'create_at': DateTime.now(),

        });
      }

      );
      //getting user info using uid that has been created in firebase auth with email and password
      /*String uid = credential.user!.uid;

      //Save user data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'username': _usernameController.text.trim(),
        'full_name': _fullnameController.text.trim(),
        'email': _emailController.text.trim(),
        'security_question': _selectedSecurityQuestion,
        'security_answer': _securityAnswerController.text.trim(),
        'create_at': DateTime.now(),

      });*/

      //Showing Login Success in a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration Successful"),
            backgroundColor: Colors.green,
          ),
      );

      //Redirect to Login Page
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
      );

    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The password provided is too weak.'))
        );
      } else if (e.code == 'email-already-in-use') {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The account already exists for that email.'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC1B6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ---------- Header ----------
            ClipPath(
              clipper: BottomWaveClipper(),
              child: Container(
                height: 370,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF8A80), Color(0xFFFF5252)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 80,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Sign Up",
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Create your DriveMind account",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---------- Form ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username
                    const Text("Username",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline),
                        hintText: "Enter a username",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter username';
                        } else if (!_isValidUsername(value)) {
                          return 'Invalid username format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Full Name
                    const Text("Full Name",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _fullnameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.badge_outlined),
                        hintText: "Enter your full name",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter full name';
                        } else if (!_isValidFullName(value)) {
                          return 'Full name must contain only letters and spaces';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    const Text("E-mail",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        hintText: "demo@email.com",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        } else if (!_isValidEmail(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    const Text("Password",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: "Enter your password",
                        counterText:
                            '${_passwordController.text.length}/24 characters',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(() =>
                              _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      maxLength: 24,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter password';
                        } else if (!_isValidPassword(value)) {
                          return 'Password must have 1 uppercase, 1 lowercase, and 1 number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 🔒 Security Question Dropdown
                    const Text("Security Question",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.question_mark_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      value: _selectedSecurityQuestion,
                      hint: const Text("Select a security question"),
                      items: _securityQuestions
                          .map((question) => DropdownMenuItem(
                                value: question,
                                child: Text(question),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSecurityQuestion = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a security question';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 🔑 Security Answer
                    const Text("Security Answer",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _securityAnswerController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.key_rounded),
                        hintText: "Enter your answer",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your answer';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // ---------- Sign Up Button ----------
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5252),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            await signUpToFirebase();
                          }
                        },
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---------- Already Member ----------
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginPage()),
                          );
                        },
                        child: const Text.rich(
                          TextSpan(
                            text: "Already have an account? ",
                            style: TextStyle(color: Colors.black54),
                            children: [
                              TextSpan(
                                text: "Sign in",
                                style: TextStyle(
                                  color: Color(0xFFFF5252),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Custom Wave ----------
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
        firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);
    path.quadraticBezierTo(
        secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
