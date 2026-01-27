import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_page.dart';
import 'client_signup_page.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with TickerProviderStateMixin {
  // ==================== DATABASE CONFIG ====================
  static const String databaseName = 'truxoodriver';
  late FirebaseFirestore _db;

  // Constants
  static const Duration _animationDuration = Duration(milliseconds: 800);
  static const Duration _staggerDelay = Duration(milliseconds: 200);
  static const Duration _transitionDuration = Duration(milliseconds: 500);
  static const double _largeScreenBreakpoint = 600;
  static const double _contentWidthRatio = 0.8;
  static const double _horizontalPaddingRatio = 0.05;
  static const int _phoneNumberLength = 10;
  static const String _countryCode = '+91';

  // Controllers
  late final TextEditingController _contactNumberController;
  late final FocusNode _phoneFocusNode;

  // Animations
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _buttonController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonScaleAnimation;

  bool _isLoading = false;
  bool _isValidNumber = false;

  @override
  void initState() {
    super.initState();
    
    // 1. Initialize Named Database
    try {
      _db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: databaseName,
      );
    } catch (e) {
      print("⚠️ DB Connection Error: $e");
      _db = FirebaseFirestore.instance;
    }

    _initializeControllers();
    _initializeAnimations();
    _startAnimations();

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _phoneFocusNode.requestFocus();
    });
  }

  void _initializeControllers() {
    _contactNumberController = TextEditingController();
    _phoneFocusNode = FocusNode();
    _contactNumberController.addListener(_validatePhoneNumber);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(duration: _animationDuration, vsync: this);
    _slideController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _buttonController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _buttonScaleAnimation = CurvedAnimation(parent: _buttonController, curve: Curves.elasticOut);
  }

  void _startAnimations() {
    _fadeController.forward();
    Future.delayed(_staggerDelay, () { if (mounted) _slideController.forward(); });
    Future.delayed(const Duration(milliseconds: 600), () { if (mounted) _buttonController.forward(); });
  }

  void _validatePhoneNumber() {
    final phoneNumber = _contactNumberController.text.replaceAll(RegExp(r'[^\d]'), '');
    final isValid = phoneNumber.length == _phoneNumberLength && RegExp(r'^[6-9]\d{9}$').hasMatch(phoneNumber);

    if (_isValidNumber != isValid) {
      setState(() => _isValidNumber = isValid);
    }
  }

  @override
  void dispose() {
    _contactNumberController.dispose();
    _phoneFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  // ==================== LOGIC: SIGN UP NAVIGATION ====================
  // New function to handle the "Sign Up" button click
  void _handleSignUpNavigation() {
    final contact = _contactNumberController.text.replaceAll(RegExp(r'[^\d]'), '');

    // Check if input is valid
    if (!_isValidNumber || contact.length != _phoneNumberLength) {
      _showErrorSnackBar("Please enter your 10-digit mobile number above to Sign Up");
      if (mounted) _phoneFocusNode.requestFocus(); // Focus the text field
      return;
    }

    // Navigate to OTP Page with isExistingUser = false (New User Flow)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpPage(
          phoneNumber: contact, // ✅ Pass the actual number
          isExistingUser: false, // ✅ Tells OtpPage to go to Registration
        ),
      ),
    );
  }

  // ==================== LOGIC: LOGIN (SEND OTP) ====================
  
  void _handleNext() async {
    final contact = _contactNumberController.text.replaceAll(RegExp(r'[^\d]'), '');

    if (!_isValidNumber || contact.length != _phoneNumberLength) {
      _showErrorSnackBar('Please enter a valid 10-digit phone number');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final raw = contact;
      final formatted = "+91$raw";
      final searchNums = [raw, formatted];
      
      final fieldNames = ['phoneNumber', 'phone_number', 'mobile', 'phone'];
      
      print("🔍 [DEBUG] Checking DB '$databaseName' for: $searchNums");

      // 1. CHECK DRIVERS COLLECTION (BLOCK THEM)
      bool driverFound = false;
      for (String field in fieldNames) {
        if(driverFound) break;
        final q = await _db.collection('drivers').where(field, whereIn: searchNums).limit(1).get();
        if (q.docs.isNotEmpty) driverFound = true;
      }

      if (driverFound) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackBar("Account registered as a driver. Please use Driver App.");
        }
        return;
      }

      // 2. CHECK CLIENTS COLLECTION
      bool clientFound = false;
      for (String field in fieldNames) {
        if(clientFound) break;
        final q = await _db.collection('clients').where(field, whereIn: searchNums).limit(1).get();
        if (q.docs.isNotEmpty) clientFound = true;
      }

      // 3. NAVIGATE TO OTP PAGE
      if (mounted) {
        setState(() => _isLoading = false);
        
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => OtpPage(
              phoneNumber: contact, 
              isExistingUser: clientFound // Logic: True = Home, False = Signup
            ),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
            transitionDuration: _transitionDuration,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar("Connection Error: $e");
        print("❌ DB Error: $e");
      }
    }
  }

  void _showErrorSnackBar(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: Colors.red, 
      behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20)
    ));
  }

  // ==================== UI WIDGETS ====================

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final sizes = _getResponsiveSizes(screenWidth, screenHeight);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(sizes['appBarHeight']!),
        child: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, size: sizes['appBarHeight']! > 55 ? 28 : 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
          elevation: 0, backgroundColor: Colors.white,
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(screenWidth, screenHeight, sizes),
              SizedBox(height: sizes['verticalSpacing']!),
              _buildPhoneInput(screenWidth, sizes),
              SizedBox(height: sizes['buttonSpacing']!),
              _buildNextButton(screenWidth, sizes),
              SizedBox(height: screenHeight * 0.03),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, double> _getResponsiveSizes(double w, double h) {
    final isL = w > _largeScreenBreakpoint;
    return {
      'titleFontSize': isL ? 42.0 : 36.0, 'subtitleFontSize': isL ? 14.0 : 12.0,
      'inputFontSize': isL ? 18.0 : 16.0, 'buttonFontSize': isL ? 18.0 : 16.0,
      'verticalSpacing': isL ? h * 0.06 : h * 0.04, 'buttonSpacing': isL ? h * 0.07 : h * 0.04,
      'appBarHeight': isL ? 60.0 : 50.0, 'buttonHeight': isL ? 60.0 : 47.0,
    };
  }

  Widget _buildHeader(double w, double h, Map<String, double> sizes) {
    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: EdgeInsets.only(left: w * _horizontalPaddingRatio, right: w * _horizontalPaddingRatio, top: h * 0.02),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Enter Phone Number for verification', style: TextStyle(fontSize: sizes['titleFontSize'], fontWeight: FontWeight.w600, color: Colors.black87, height: 1.2)),
          SizedBox(height: h * 0.01),
          Text('This number will be used for all transport related communication.', style: TextStyle(fontSize: sizes['subtitleFontSize'], color: const Color(0xFF5F5353), height: 1.4)),
        ]),
      ),
    );
  }

  Widget _buildPhoneInput(double w, Map<String, double> sizes) {
    return SlideTransition(
      position: _slideAnimation,
      child: SizedBox(
        width: w * _contentWidthRatio,
        child: TextField(
          controller: _contactNumberController,
          focusNode: _phoneFocusNode,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          style: TextStyle(fontSize: sizes['inputFontSize'], fontWeight: FontWeight.w500),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, _PhoneNumberFormatter()],
          decoration: InputDecoration(
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _isValidNumber ? Colors.green : Colors.blue, width: 2)),
            prefixText: '$_countryCode ',
            prefixStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: sizes['inputFontSize']),
            hintText: 'Enter your phone number',
            suffixIcon: _contactNumberController.text.isNotEmpty ? Icon(_isValidNumber ? Icons.check_circle : Icons.error, color: _isValidNumber ? Colors.green : Colors.red) : null,
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton(double w, Map<String, double> sizes) {
    return Column(children: [
      // 1. Send OTP Button
      ScaleTransition(
        scale: _buttonScaleAnimation,
        child: TextButton(
          onPressed: _isLoading ? null : _handleNext,
          style: TextButton.styleFrom(
            backgroundColor: _isValidNumber ? Colors.black : Colors.grey[300],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: Size(w * _contentWidthRatio, sizes['buttonHeight']!),
          ),
          child: _isLoading
              ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_isValidNumber ? Colors.white : Colors.grey[600]!)))
              : Text('Send OTP', style: TextStyle(color: _isValidNumber ? Colors.white : Colors.grey[600], fontSize: sizes['buttonFontSize'], fontWeight: FontWeight.w500)),
        ),
      ),
      const SizedBox(height: 16),
      
      // 2. Sign Up Link (Updated to use _handleSignUpNavigation)
      FadeTransition(
        opacity: _fadeAnimation,
        child: TextButton(
          onPressed: _handleSignUpNavigation, // <--- Use the new handler here!
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: sizes['buttonFontSize']! - 2, color: Colors.grey[600]), 
              children: [
                const TextSpan(text: "Don't have an account? "), 
                TextSpan(text: "Sign Up", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, decoration: TextDecoration.underline))
              ]
            )
          ),
        ),
      ),
    ]);
  }
}

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    final d = n.text.replaceAll(RegExp(r'[^\d]'), '');
    if (d.length > 10) return o;
    if (d.length > 5) return TextEditingValue(text: '${d.substring(0, 5)} ${d.substring(5)}', selection: TextSelection.collapsed(offset: d.length + 1));
    return n;
  }
}