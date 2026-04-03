// pages/splash_screen.dart
import 'package:flutter/material.dart';
import 'get_started_page.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () async {
      final apiService = ApiService();
      
      // Ping server (esp. for Render free tier wakeup)
      apiService.testConnection().ignore();
      
      final user = await apiService.getStoredUser();

      if (mounted) {
        if (user != null) {
          Navigator.pushReplacementNamed(context, '/dashboard',
              arguments: user);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const GetStartedPage()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'app-logo',
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.eco,
                  size: 80,
                  color: Colors.green.shade700,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Annadanam',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Food Charity',
              style: TextStyle(
                fontSize: 18,
                color: Colors.green.shade600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.green.shade700,
                ),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
