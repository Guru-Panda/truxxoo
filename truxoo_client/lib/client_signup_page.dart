import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dataclient_service.dart';
import 'client_side_home.dart';
import 'firebase_config.dart';

class CustomerRegistrationConstants {
  static const double largeScreenBreakpoint = 600;
  static const double horizontalPadding = 16.0;
  static const double verticalSpacing = 16.0;
  static const double sectionSpacing = 24.0;
  static const double imagePickerHeight = 120.0;
  static const double buttonHeight = 50.0;
}

class CustomerRegistrationValidator {
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your name';
    if (value.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? validateMobile(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your mobile number';
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length != 10) return 'Please enter a valid 10-digit number';
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email address';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validateCompanyName(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your company name';
    if (value.length < 2) return 'Company name must be at least 2 characters';
    return null;
  }

  static String? validateRegistrationNumber(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.length < 6) return 'Registration number must be at least 6 characters';
    return null;
  }
}

// ==================== REGISTRATION CHECK RESULT ====================
class RegistrationCheckResult {
  final bool exists;
  final String? userType; // 'client' or 'driver'
  final String? message;

  RegistrationCheckResult({
    required this.exists,
    this.userType,
    this.message,
  });
}

class CustomerRegistrationPage extends StatefulWidget {
  final String? phoneNumber;

  const CustomerRegistrationPage({
    Key? key,
    this.phoneNumber,
  }) : super(key: key);

  @override
  State<CustomerRegistrationPage> createState() => _CustomerRegistrationPageState();
}

class _CustomerRegistrationPageState extends State<CustomerRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _registrationNumberController = TextEditingController();

  // Profile photo
  File? _profilePhoto;

  bool _isLoading = false;

  // Database reference
  final FirebaseFirestore _db = FirebaseConfig.instance.db;

  @override
  void initState() {
    super.initState();
    if (widget.phoneNumber != null) {
      _mobileController.text = widget.phoneNumber!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _companyNameController.dispose();
    _registrationNumberController.dispose();
    super.dispose();
  }

  // ==================== CHECK IF NUMBER EXISTS ====================
  
  /// Checks if phone number exists in clients or drivers collection
  /// Returns specific message based on where it's found
  Future<RegistrationCheckResult> _checkPhoneNumberExists(String phoneNumber) async {
    try {
      // Clean the phone number
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      final formattedPhone = '+91$cleanPhone';

      print("🔍 Checking if phone exists: $formattedPhone");

      // ===== Check in CLIENTS collection first =====
      QuerySnapshot clientQuery = await _db
          .collection('clients')
          .where('phone_number', isEqualTo: formattedPhone)
          .limit(1)
          .get();

      if (clientQuery.docs.isNotEmpty) {
        print("⚠️ Phone found in CLIENTS collection");
        return RegistrationCheckResult(
          exists: true,
          userType: 'client',
          message: 'Already registered.',
        );
      }

      // Try alternate format for clients
      clientQuery = await _db
          .collection('clients')
          .where('phone_number', isEqualTo: cleanPhone)
          .limit(1)
          .get();

      if (clientQuery.docs.isNotEmpty) {
        print("⚠️ Phone found in CLIENTS collection (alt format)");
        return RegistrationCheckResult(
          exists: true,
          userType: 'client',
          message: 'Already registered.',
        );
      }

      // ===== Check in DRIVERS collection =====
      QuerySnapshot driverQuery = await _db
          .collection('drivers')
          .where('phone_number', isEqualTo: formattedPhone)
          .limit(1)
          .get();

      if (driverQuery.docs.isNotEmpty) {
        print("⚠️ Phone found in DRIVERS collection");
        return RegistrationCheckResult(
          exists: true,
          userType: 'driver',
          message: 'Number already registered as a driver.',
        );
      }

      // Try alternate format for drivers
      driverQuery = await _db
          .collection('drivers')
          .where('phone_number', isEqualTo: cleanPhone)
          .limit(1)
          .get();

      if (driverQuery.docs.isNotEmpty) {
        print("⚠️ Phone found in DRIVERS collection (alt format)");
        return RegistrationCheckResult(
          exists: true,
          userType: 'driver',
          message: 'Number already registered as a driver.',
        );
      }

      // Phone number not found in any collection
      print("✅ Phone number is available for registration");
      return RegistrationCheckResult(
        exists: false,
        message: null,
      );

    } catch (e) {
      print("❌ Error checking phone: $e");
      // Return false to allow registration attempt (will fail at Firebase if duplicate)
      return RegistrationCheckResult(
        exists: false,
        message: null,
      );
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800.0,
        maxHeight: 800.0,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _profilePhoto = File(image.path);
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking image: $e');
      }
    }
  }

  Widget _buildProfileImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Profile Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickProfileImage,
          child: Container(
            height: CustomerRegistrationConstants.imagePickerHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: _profilePhoto != null ? Colors.green : Colors.grey,
                width: _profilePhoto != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: _profilePhoto != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _profilePhoto!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_add_outlined,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload your photo\n(Required for verification)',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ==================== SUBMIT REGISTRATION ====================
  Future<void> _submitRegistrationForm() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fill all required fields correctly');
      return;
    }

    // Check profile photo
    if (_profilePhoto == null) {
      _showErrorSnackBar('Please upload your profile photo');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      // 1. Check if phone number already exists
      final checkResult = await _checkPhoneNumberExists(_mobileController.text);

      if (checkResult.exists) {
        setState(() => _isLoading = false);
        
        // Show specific error message based on user type
        if (checkResult.userType == 'driver') {
          _showErrorSnackBar('Number already registered as a driver.');
        } else {
          _showErrorSnackBar('Already registered.');
        }
        return;
      }

      // 2. Show progress dialog
      _showProgressDialog();

      // 3. Create Data Object
      final registrationData = ClientRegistrationData(
        name: _nameController.text.trim(),
        phoneNumber: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        companyName: _companyNameController.text.trim(),
        companyRegNumber: _registrationNumberController.text.trim(),
        profilePhoto: _profilePhoto!,
      );

      // 4. Call Service to register
      final result = await ClientDataService.registerClient(data: registrationData);

      // 5. Close progress dialog
      if (mounted) Navigator.of(context).pop();

      // 6. Handle Result
      if (result.success) {
        setState(() => _isLoading = false);
        HapticFeedback.mediumImpact();
        _showSuccessSnackBar('Registration successful!');

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          // Navigate to Client Home
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => ClientSideHome(
                displayName: _nameController.text,
                displayProfilePicture: result.downloadUrl ?? '',
                isUsingLocalImage: false,
                clientPhone: _mobileController.text,
                clientEmail: _emailController.text,
                companyName: _companyNameController.text,
                companyRegNumber: _registrationNumberController.text,
              ),
            ),
            (route) => false,
          );
        }
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar(result.message ?? 'Registration failed');
      }
    } catch (e) {
      // Close dialog if open
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  void _showProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Creating your account...'),
            const SizedBox(height: 8),
            Text(
              'Uploading photo & saving details',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: const Text("Customer Registration"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CustomerRegistrationConstants.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phone Verified Banner
              if (widget.phoneNumber != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Phone verified: +91 ${widget.phoneNumber}',
                          style: TextStyle(color: Colors.green[700]),
                        ),
                      ),
                    ],
                  ),
                ),

              // Profile Information Section
              _buildSectionHeader('Profile Information'),
              const SizedBox(height: CustomerRegistrationConstants.verticalSpacing),

              _buildProfileImageSection(),
              const SizedBox(height: CustomerRegistrationConstants.verticalSpacing),

              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration('Full Name *'),
                validator: CustomerRegistrationValidator.validateName,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: CustomerRegistrationConstants.verticalSpacing),

              TextFormField(
                controller: _mobileController,
                decoration: _buildInputDecoration('Mobile Number *'),
                keyboardType: TextInputType.phone,
                enabled: widget.phoneNumber == null,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _MobileNumberFormatter(),
                ],
                validator: CustomerRegistrationValidator.validateMobile,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: CustomerRegistrationConstants.verticalSpacing),

              TextFormField(
                controller: _emailController,
                decoration: _buildInputDecoration('Email Address *'),
                keyboardType: TextInputType.emailAddress,
                validator: CustomerRegistrationValidator.validateEmail,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: CustomerRegistrationConstants.sectionSpacing),

              // Company Information Section
              _buildSectionHeader('Company Information'),
              const SizedBox(height: CustomerRegistrationConstants.verticalSpacing),

              TextFormField(
                controller: _companyNameController,
                decoration: _buildInputDecoration('Company Name *'),
                validator: CustomerRegistrationValidator.validateCompanyName,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: CustomerRegistrationConstants.verticalSpacing),

              TextFormField(
                controller: _registrationNumberController,
                decoration: _buildInputDecoration('Registration Number (Optional)'),
                validator: CustomerRegistrationValidator.validateRegistrationNumber,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: CustomerRegistrationConstants.sectionSpacing),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: CustomerRegistrationConstants.buttonHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRegistrationForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, {IconData? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}

// ==================== TEXT FORMATTER ====================
class _MobileNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length > 10) {
      final limitedDigits = digitsOnly.substring(0, 10);
      return TextEditingValue(
        text: _formatMobileNumber(limitedDigits),
        selection: TextSelection.collapsed(offset: _formatMobileNumber(limitedDigits).length),
      );
    }
    final formattedText = _formatMobileNumber(digitsOnly);
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }

  String _formatMobileNumber(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 5) return digits;
    return '${digits.substring(0, 5)} ${digits.substring(5)}';
  }
}