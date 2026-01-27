import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truxoo_client_new/client_side_home.dart';
import 'package:truxoo_client_new/client_signup_page.dart'; // Import Signup Page

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  final bool isExistingUser; // Added this parameter
  final String verificationId;

  const OtpPage({
    super.key,
    required this.phoneNumber,
    required this.isExistingUser, // Require this
    this.verificationId = '',
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  // ==================== CONFIGURATION ====================
  static const String databaseName = 'truxoodriver';
  static const int _otpLength = 6;

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = 30;
  Timer? _resendTimer;
  String? _currentVerificationId;
  late FirebaseFirestore _db;

  @override
  void initState() {
    super.initState();
    // Initialize DB
    try {
      _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: databaseName);
    } catch (e) {
      _db = FirebaseFirestore.instance;
    }

    _startResendTimer();

    // Trigger OTP Send immediately
    _sendFirebaseOtp();
    
    Future.delayed(const Duration(milliseconds: 500), () => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // 1. Send OTP via Firebase
  Future<void> _sendFirebaseOtp() async {
    print("🚀 Sending OTP to: +91${widget.phoneNumber}");
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${widget.phoneNumber}',
        
        // A. AUTO VERIFICATION (Android only)
        verificationCompleted: (PhoneAuthCredential c) async {
          print("✅ Auto-verification Success!");
          await FirebaseAuth.instance.signInWithCredential(c);
          _handleAuthSuccess(); // Go to next screen
        },
        
        // B. FAILURE
        verificationFailed: (FirebaseAuthException e) {
          print("❌ Send Failed: Code=${e.code}, Msg=${e.message}");
          _msg('Send Failed: ${e.message}', true);
        },
        
        // C. CODE SENT
        codeSent: (String vid, int? token) {
          print("📩 OTP Initiated. Verification ID: $vid");
          if(mounted) {
            setState(() => _currentVerificationId = vid);
            _msg('OTP Sent', false);
          }
        },
        
        // D. TIMEOUT
        codeAutoRetrievalTimeout: (String vid) {
          if(mounted) setState(() => _currentVerificationId = vid);
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      print("❌ General Error: $e");
      _msg('Error sending OTP: $e', true);
    }
  }

  // 2. Verify OTP Logic
  Future<bool> _verifyFirebaseOtp(String otp) async {
    if (_currentVerificationId == null) {
      _msg("Please wait, connecting to server...", true);
      return false;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId!,
        smsCode: otp,
      );

      // Attempt Sign In
      await FirebaseAuth.instance.signInWithCredential(credential);
      print("✅ Sign In Successful!");
      return true;
    } on FirebaseAuthException catch (e) {
      print("❌ Auth Failed: ${e.message}");
      String errorMsg = "Invalid OTP";
      if (e.code == 'invalid-verification-code') errorMsg = "Incorrect OTP code.";
      if (e.code == 'session-expired') errorMsg = "OTP Expired. Resend it.";
      _msg(errorMsg, true);
      return false;
    } catch (e) {
      _msg("Error: $e", true);
      return false;
    }
  }

  // 3. Trigger Verification
  void _verifyAndLogin() async {
    final otp = _otpController.text.trim();
    if (otp.length < _otpLength) return _msg('Enter valid OTP', true);

    setState(() => _isLoading = true);

    bool isValid = await _verifyFirebaseOtp(otp);

    if (isValid) {
      _handleAuthSuccess();
    } else {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // 4. Handle Navigation based on isExistingUser
  Future<void> _handleAuthSuccess() async {
    // === SCENARIO 1: NEW USER ===
    if (!widget.isExistingUser) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CustomerRegistrationPage(phoneNumber: widget.phoneNumber)
          ),
        );
      }
      return;
    }

    // === SCENARIO 2: EXISTING USER (Fetch Data & Login) ===
    try {
      final raw = widget.phoneNumber;
      final formatted = "+91$raw";
      final searchNums = [raw, formatted];
      final fields = ['phone_number', 'phoneNumber', 'phone', 'mobile'];

      Map<String, dynamic>? data;

      // Find user in DB
      for(String f in fields) {
        if(data != null) break;
        final query = await _db.collection('clients').where(f, whereIn: searchNums).limit(1).get();
        if(query.docs.isNotEmpty) data = query.docs.first.data();
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => ClientSideHome(
            displayName: data?['full_name'] ?? data?['name'] ?? 'User',
            displayProfilePicture: data?['profile_photo_url'] ?? '',
            isUsingLocalImage: false,
            clientPhone: widget.phoneNumber,
            clientEmail: data?['email'] ?? '',
            companyName: data?['company_name'] ?? '',
            companyRegNumber: data?['company_reg_number'] ?? '',
          )),
          (route) => false,
        );
      }
    } catch (e) {
      _msg("Data Load Error: $e", true);
      setState(() => _isLoading = false);
    }
  }

  void _msg(String txt, bool isError) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(txt), backgroundColor: isError ? Colors.red : Colors.blue,
      behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20)
    ));
  }

  void _resendOtp() {
    setState(() => _isLoading = true);
    _sendFirebaseOtp();
    
    Future.delayed(const Duration(seconds: 1), () {
      setState(() { _isLoading = false; _resendCountdown = 30; _canResend = false; });
      _startResendTimer();
    });
  }

  void _startResendTimer() {
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) _resendCountdown--;
          else { _canResend = true; timer.cancel(); }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP"), elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text("Enter OTP sent to +91 ${widget.phoneNumber}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            TextField(
              controller: _otpController,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              maxLength: _otpLength,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(hintText: "000000"),
              onChanged: (val) { if(val.length == _otpLength) _verifyAndLogin(); },
            ),
            const SizedBox(height: 30),
            _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _currentVerificationId == null ? null : _verifyAndLogin,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                  child: Text(_currentVerificationId == null ? "Connecting..." : "Verify & Proceed", style: const TextStyle(color: Colors.white)),
                ),
            const SizedBox(height: 20),
            if(_canResend) TextButton(onPressed: _resendOtp, child: const Text("Resend OTP"))
            else Text("Resend in $_resendCountdown s", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}