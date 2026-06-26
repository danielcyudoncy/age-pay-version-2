// features/splash/screens/splash_screen.dart
import 'package:cls/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _cached = false;

  @override
  void initState() {
    super.initState();
    // Navigate to the login screen after a delay
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_cached) {
      _cached = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        precacheImage(const AssetImage('assets/images/logo.png'), context);
      });
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: Image.asset('assets/images/logo.png')),
    );
  }
}
