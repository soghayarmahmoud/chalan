import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'language_selection_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();

    // Check auth status after the animation completes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkAuthStatus();
      }
    });
  }

  Future<void> _checkAuthStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // No logged-in user, navigate to the Login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      // User is logged in, now check for language data
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists && userDoc.data()!.containsKey('spoken_language') && userDoc.data()!.containsKey('learning_language')) {
        // Language data exists, go to the Main screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        // Language data is missing, go to the Language Selection screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LanguageSelectionScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Adjusted gradient for a softer look
    final backgroundGradient = LinearGradient(
      colors: isDark
          ? [darkThemeColor, primaryColor.withOpacity(0.2)]
          : [lightThemeColor, primaryColor.withOpacity(0.2)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _animation,
                child: Icon(
                  FontAwesomeIcons.solidCommentDots,
                  size: 100.0,
                  color: Theme.of(context).primaryColor, // Icon color is now the primary color
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Chalan',
                style: TextStyle(
                  fontSize: 60, // Increased font size
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor, // Text color is now the primary color
                  shadows: [
                    Shadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                      blurRadius: 10.0,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Learn languages with chat',
                style: TextStyle(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 50),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}