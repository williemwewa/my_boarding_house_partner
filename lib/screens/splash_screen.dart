import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_boarding_house_partner/screens/landloard/landlord_dashboard.dart';
import 'package:provider/provider.dart';

import 'package:my_boarding_house_partner/providers/auth_provider.dart';
import 'package:my_boarding_house_partner/screens/auth/phone_login_screen.dart';

import 'package:my_boarding_house_partner/screens/admin/admin_dashboard.dart';
import 'package:my_boarding_house_partner/screens/auth/profile_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _checkAuthStatus() async {
    // Simulate splash screen delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is signed in, check role and profile
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);

      // Wait for auth provider to fetch user data
      if (authProvider.userData == null) {
        // If userData is not already loaded, wait a bit more
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!mounted) return;

      // Check if user is new and needs to complete profile
      bool isNewUser = await authProvider.checkIfNewUser();

      if (isNewUser) {
        _navigateToProfileSetup();
        return;
      }

      // Navigate based on user role
      if (authProvider.userRole == UserRole.landlord) {
        _navigateToLandlordDashboard();
      } else if (authProvider.userRole == UserRole.admin) {
        _navigateToAdminDashboard();
      } else {
        // If somehow a student logs in to landlord app, still send to profile setup
        _navigateToProfileSetup();
      }
    } else {
      // No user, navigate to login
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PhoneLoginScreen()));
  }

  void _navigateToProfileSetup() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const UserProfileSetupScreen()));
  }

  void _navigateToLandlordDashboard() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LandlordDashboard()));
  }

  void _navigateToAdminDashboard() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AdminDashboard()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo or app name
            const Text("My Boarding House Partner", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2B7E))),
            const SizedBox(height: 24),
            // Loading indicator
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F2B7E))),
            const SizedBox(height: 48),
            // App version
            Text("Version 1.0.0", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
