import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 ADDED THIS
import 'package:truxoo_client_new/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// SCREEN IMPORTS
import 'onboarding_page.dart'; 
import 'client_side_home.dart'; // 🔥 Make sure to import your actual Driver Home Screen!

void main() async {
  // 1. Ensures Flutter framework is fully booted
  WidgetsFlutterBinding.ensureInitialized(); 

  await dotenv.load(fileName: ".env");
  
  // 2. Connects your app to Firebase before any screens load
  await Firebase.initializeApp(); 

  // 3. Boots up the app wrapper
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Unload', 
      home: Builder(
        builder: (context) {
          return TypingSplashScreen(
            initializationTask: () async {
              // Any background data loading can happen here
            },
            onReady: () {
              // 🔥 FIX: Check Firebase Auth State when the animation finishes
              final user = FirebaseAuth.instance.currentUser;

              if (user != null) {
                // ✅ User is already logged in -> Send them to the Home Dashboard
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const ClientSideHome()), // Replace with your actual Driver Home Screen
                );
              } else {
                // ❌ Not logged in -> Send them to Onboarding
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const OnboardingPage()),
                );
              }
            },
          );
        }
      ),
    );
  }
}