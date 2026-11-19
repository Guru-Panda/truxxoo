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
    if (value == null || value.isEmpty) return 'Please enter registration number';
    if (value.length < 3) return 'Invalid registration number';
    return null;
  }
}

// ==================== REGISTRATION CHECK RESULT ====================
class RegistrationCheckResult {
  final bool exists;
  final bool hasError;
  final String? userType; 
  final String? message;

  RegistrationCheckResult({
    required this.exists,
    this.hasError = false,
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

  // Images
  File? _profilePhoto;
  File? _gstImage;
  File? _panImage; 

  bool _isLoading = false;

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
  Future<RegistrationCheckResult> _checkPhoneNumberExists(String phoneNumber) async {
    try {
      final raw = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      final formattedPhone = '+91$raw';
      final searchNums = [raw, formattedPhone];

      final clientQuery = await _db
          .collection('clients')
          .where('phone_number', whereIn: searchNums) 
          .limit(1)
          .get();

      if (clientQuery.docs.isNotEmpty) {
        return RegistrationCheckResult(exists: true, userType: 'client', message: 'Already registered.');
      }

      final driverQuery = await _db
          .collection('drivers')
          .where('phone_number', whereIn: searchNums)
          .limit(1)
          .get();

      if (driverQuery.docs.isNotEmpty) {
        return RegistrationCheckResult(exists: true, userType: 'driver', message: 'Number already registered as a driver.');
      }

      return RegistrationCheckResult(exists: false, message: null);

    } catch (e) {
      return RegistrationCheckResult(
        exists: false, 
        hasError: true, 
        message: 'Network error. Unable to verify phone number. Please check your connection.'
      );
    }
  }

  // ==================== IMAGE PICKER LOGIC ====================
  Future<void> _pickImage(Function(File) onSelected) async {
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
          onSelected(File(image.path));
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error picking image: $e');
    }
  }

  // ==================== REUSABLE IMAGE WIDGET ====================
  // MODIFIED: Added isRequired flag (defaults to true)
  Widget _buildImagePickerWidget({
    required String label, 
    required File? imageFile, 
    required VoidCallback onTap,
    String? subLabel,
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
              ),
              // MODIFIED: Conditionally show the asterisk
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
            ],
          ),
        ),
        if (subLabel != null) ...[
          const SizedBox(height: 4),
          Text(subLabel, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: CustomerRegistrationConstants.imagePickerHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: imageFile != null ? Colors.green : Colors.grey,
                width: imageFile != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: imageFile != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          imageFile,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          cacheWidth: 400, 
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
                        Icons.add_a_photo_outlined,
                        size: 30,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload',
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

  // ==================== SUBMIT FORM ====================
  Future<void> _submitRegistrationForm() async {
    // 1. Validate Text Fields
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fill all required fields correctly');
      return;
    }

    // 2. Validate Images
    if (_profilePhoto == null) {
      _showErrorSnackBar('Please upload your profile photo');
      return;
    }
    // MODIFIED: Removed GST image validation logic here
    if (_panImage == null) {
      _showErrorSnackBar('Please upload PAN Card for KYC');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      // 3. Check Phone Duplicate
      final checkResult = await _checkPhoneNumberExists(_mobileController.text);

      if (checkResult.hasError) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(checkResult.message ?? 'Network error.');
        return;
      }

      if (checkResult.exists) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(checkResult.message ?? 'Already registered.');
        return;
      }

      // 4. Show Loading
      _showProgressDialog();

      // 5. Prepare Data
      final registrationData = ClientRegistrationData(
        name: _nameController.text.trim(),
        phoneNumber: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        companyName: _companyNameController.text.trim(),
        companyRegNumber: _registrationNumberController.text.trim(),
        profilePhoto: _profilePhoto!,
        gstImage: _gstImage, // MODIFIED: Removed the ! so nulls are accepted
        panImage: _panImage!,
      );

      // 6. Call Service
      final result = await ClientDataService.registerClient(data: registrationData);

      // 7. Dismiss Loading
      if (mounted) Navigator.of(context).pop();

      // 8. Handle Result
      if (result.success) {
        setState(() => _isLoading = false);
        HapticFeedback.mediumImpact();
        _showSuccessSnackBar('Registration successful! KYC Pending.');

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
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
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  // ==================== UI HELPERS ====================
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
            const Text('Creating account...'),
            const SizedBox(height: 8),
            Text(
              'Uploading KYC documents may take a moment',
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

              // ================= SECTION 1: PROFILE =================
              _buildSectionHeader('Profile Information'),
              const SizedBox(height: CustomerRegistrationConstants.verticalSpacing),

              _buildImagePickerWidget(
                label: 'Profile Photo',
                subLabel: '(For your avatar)',
                imageFile: _profilePhoto,
                onTap: () => _pickImage((f) => _profilePhoto = f),
              ),
              
              const SizedBox(height: CustomerRegistrationConstants.verticalSpacing),

              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration('Full Name *'),
                validator: CustomerRegistrationValidator.validateName,
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
              ),
              const SizedBox(height: CustomerRegistrationConstants.verticalSpacing),

              TextFormField(
                controller: _emailController,
                decoration: _buildInputDecoration('Email Address *'),
                keyboardType: TextInputType.emailAddress,
                validator: CustomerRegistrationValidator.validateEmail,
              ),
              const SizedBox(height: CustomerRegistrationConstants.sectionSpacing),

              // ================= SECTION 2: COMPANY =================
              _buildSectionHeader('Company Information'),
              const SizedBox(height: CustomerRegistrationConstants.verticalSpacing),

              TextFormField(
                controller: _companyNameController,
                decoration: _buildInputDecoration('Company Name *'),
                validator: CustomerRegistrationValidator.validateCompanyName,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: CustomerRegistrationConstants.verticalSpacing),

              TextFormField(
                controller: _registrationNumberController,
                decoration: _buildInputDecoration('Registration Number *'),
                validator: CustomerRegistrationValidator.validateRegistrationNumber,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: CustomerRegistrationConstants.sectionSpacing),

              // ================= SECTION 3: KYC =================
              _buildSectionHeader('KYC Verification'),
              const SizedBox(height: 8),
              Text(
                'Please upload clear photos of the following documents.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: CustomerRegistrationConstants.verticalSpacing),

              Row(
                children: [
                  Expanded(
                    child: _buildImagePickerWidget(
                      label: 'GST Document',
                      subLabel: '(Optional)',
                      isRequired: false, // MODIFIED: Sets asterisk rendering to false
                      imageFile: _gstImage,
                      onTap: () => _pickImage((f) => _gstImage = f),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildImagePickerWidget(
                      label: 'PAN Card',
                      imageFile: _panImage,
                      onTap: () => _pickImage((f) => _panImage = f),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),

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
                    disabledForegroundColor: Colors.grey[500],
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

  InputDecoration _buildInputDecoration(String label) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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