import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'client_side_home.dart';
import 'onboarding_page.dart';

class MyAccountClient extends StatefulWidget {
  final String? currentProfileImagePath;
  final bool isLocalImage;
  final String clientName;
  final String clientPhone;
  final String clientEmail;
  final String companyName;
  final String companyRegNumber;

  const MyAccountClient({
    super.key, 
    this.currentProfileImagePath,
    this.isLocalImage = false,
    this.clientName = "Guru Prasad Panda",
    this.clientPhone = "8875658758",
    this.clientEmail = "guru34@gmail.com",
    this.companyName = "ABC Logistics",
    this.companyRegNumber = "REG123456789",
  });

  @override
  State<MyAccountClient> createState() => _MyAccountClientState();
}

class _MyAccountClientState extends State<MyAccountClient> {
  late String _clientName;
  late String _clientPhone;
  late String _clientEmail;
  late String _companyName;
  late String _companyRegNumber;
  
  final String _profilePicture = 'assets/client_image.webp';
  File? _newProfileImage;
  bool _isUsingLocalImage = false;
  bool _isEditingProfile = false;
  bool _isEditingCompany = false;
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _companyNameController;
  late TextEditingController _companyRegController;

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_backButtonInterceptor);
    
    _clientName = widget.clientName;
    _clientPhone = widget.clientPhone;
    _clientEmail = widget.clientEmail;
    _companyName = widget.companyName;
    _companyRegNumber = widget.companyRegNumber;
    _isUsingLocalImage = widget.isLocalImage;
    
    if (widget.currentProfileImagePath != null && widget.isLocalImage) {
      _newProfileImage = File(widget.currentProfileImagePath!);
    }
    
    _nameController = TextEditingController(text: _clientName);
    _emailController = TextEditingController(text: _clientEmail);
    _phoneController = TextEditingController(text: _clientPhone);
    _companyNameController = TextEditingController(text: _companyName);
    _companyRegController = TextEditingController(text: _companyRegNumber);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyNameController.dispose();
    _companyRegController.dispose();
    super.dispose();
  }

  // Back button interceptor - handles hardware back button
  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (_isEditingProfile || _isEditingCompany) {
      _showUnsavedChangesDialog();
      return true; // Prevent default back behavior
    }
    _goToHome();
    return true; // Prevent default back behavior
  }

  // Navigate to home without checking for unsaved changes
  void _goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ClientSideHome(
          displayName: _nameController.text,
          displayProfilePicture: _newProfileImage?.path ?? widget.currentProfileImagePath ?? 'assets/client_image.webp',
          isUsingLocalImage: _isUsingLocalImage,
        ),
      ),
    );
  }

  // Navigate to home with unsaved changes check (for AppBar back button)
  void _navigateToHome() {
    if (_isEditingProfile || _isEditingCompany) {
      _showUnsavedChangesDialog();
    } else {
      _goToHome();
    }
  }
  
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _newProfileImage = File(image.path);
        _isUsingLocalImage = true;
      });
    }
  }

  void _saveProfileChanges() {
    setState(() {
      _clientName = _nameController.text;
      _clientPhone = _phoneController.text;
      _clientEmail = _emailController.text;
      _isEditingProfile = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _goToHome();
      }
    });
  }

  void _saveCompanyChanges() {
    setState(() {
      _companyName = _companyNameController.text;
      _companyRegNumber = _companyRegController.text;
      _isEditingCompany = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Company details updated successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _goToHome(); // Fixed: Now passes profile data
      }
    });
  }

  Future<void> _showUnsavedChangesDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('You have unsaved changes. Do you want to discard them?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Discard changes - go back to original values
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClientSideHome(
                      displayName: widget.clientName,
                      displayProfilePicture: widget.currentProfileImagePath ?? 'assets/client_image.webp',
                      isUsingLocalImage: widget.isLocalImage,
                    ),
                  ),
                );
              },
            ),
            TextButton(
              child: const Text('Save', style: TextStyle(color: Colors.green)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (_isEditingProfile) _saveProfileChanges();
                if (_isEditingCompany) _saveCompanyChanges();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Account',
          style: TextStyle(
            fontSize: isLargeScreen ? 24 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateToHome,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Profile Information',
                            style: TextStyle(
                              fontSize: isLargeScreen ? 20 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isEditingProfile ? Icons.save : Icons.edit,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              if (_isEditingProfile) {
                                _saveProfileChanges();
                              } else {
                                setState(() {
                                  _isEditingProfile = true;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: isLargeScreen ? 60 : 50,
                              backgroundColor: Colors.white,
                              backgroundImage: _newProfileImage != null
                                  ? FileImage(_newProfileImage!)
                                  : _isUsingLocalImage && widget.currentProfileImagePath != null
                                      ? FileImage(File(widget.currentProfileImagePath!))
                                      : AssetImage(_profilePicture) as ImageProvider,
                            ),
                            if (_isEditingProfile)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                    ),
                                    onPressed: _pickImage,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildProfileField(
                        'Name',
                        _clientName,
                        _nameController,
                        isLargeScreen,
                        isEditing: _isEditingProfile,
                      ),
                      _buildProfileField(
                        'Phone',
                        _clientPhone,
                        _phoneController,
                        isLargeScreen,
                        isEditing: _isEditingProfile,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildProfileField(
                        'Email',
                        _clientEmail,
                        _emailController,
                        isLargeScreen,
                        isEditing: _isEditingProfile,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: isLargeScreen ? 24 : 16),
              
              // Company Details Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Company Details',
                            style: TextStyle(
                              fontSize: isLargeScreen ? 20 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isEditingCompany ? Icons.save : Icons.edit,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              if (_isEditingCompany) {
                                _saveCompanyChanges();
                              } else {
                                setState(() {
                                  _isEditingCompany = true;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildProfileField(
                        'Company Name',
                        _companyName,
                        _companyNameController,
                        isLargeScreen,
                        isEditing: _isEditingCompany,
                      ),
                      _buildProfileField(
                        'Registration Number',
                        _companyRegNumber,
                        _companyRegController,
                        isLargeScreen,
                        isEditing: _isEditingCompany,
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: isLargeScreen ? 24 : 16),
              
              // Account Actions Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Actions',
                        style: TextStyle(
                          fontSize: isLargeScreen ? 20 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.lock, color: Colors.blue),
                        title: const Text('Change Password'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Navigate to change password screen
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.support_agent, color: Colors.green),
                        title: const Text('Contact Support'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Navigate to support screen or launch phone/email
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text('Logout'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          _showLogoutConfirmationDialog(context, isLargeScreen);
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.delete_forever, color: Colors.red),
                        title: const Text('Delete Account'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          _showDeleteAccountConfirmationDialog(context, isLargeScreen);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: isLargeScreen ? 24 : 16),
              
              // App Version
              Center(
                child: Text(
                  'App Version: 1.0.0',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isLargeScreen ? 14 : 12,
                  ),
                ),
              ),
              SizedBox(height: isLargeScreen ? 24 : 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField(
    String label,
    String value,
    TextEditingController? controller,
    bool isLargeScreen, {
    bool isEditing = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isLargeScreen ? 16 : 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          if (isEditing && controller != null)
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isLargeScreen ? 16 : 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              style: TextStyle(
                fontSize: isLargeScreen ? 16 : 14,
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isLargeScreen ? 16 : 12,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Text(
                controller?.text ?? value,
                style: TextStyle(
                  fontSize: isLargeScreen ? 16 : 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Future<void> _showLogoutConfirmationDialog(BuildContext context, bool isLargeScreen) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const OnboardingPage()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _showDeleteAccountConfirmationDialog(BuildContext context, bool isLargeScreen) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
            style: TextStyle(height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performAccountDeletion();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _performAccountDeletion() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OnboardingPage()),
          (Route<dynamic> route) => false,
        );
      }
    });
  }
}