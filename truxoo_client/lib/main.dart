import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:truxoo_client_new/splash_screen.dart';

void main() async {
  // 3. This line is required so Flutter can talk to the native code (Android/iOS) before the app starts
  WidgetsFlutterBinding.ensureInitialized();

  // 4. Initialize Firebase
  await Firebase.initializeApp();

  runApp(
    MaterialApp(
      
      home: TypingSplashScreen(),
    )
  );
}