import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'client_side_home.dart';
import 'onboarding_page.dart';

// Firebase Imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart'; // ✅ Added for image uploads
import 'package:cached_network_image/cached_network_image.dart';

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
    this.clientName = "",
    this.clientPhone = "",
    this.clientEmail = "",
    this.companyName = "",
    this.companyRegNumber = "",
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
  String? _networkProfileUrl;
  
  final String _defaultProfilePicture = 'assets/client_imag_high.jpg';
  File? _newProfileImage;
  bool _isUsingLocalImage = false;
  
  bool _isEditingProfile = false;
  bool _isEditingCompany = false;
  bool _isLoading = true; 
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _companyNameController;
  late TextEditingController _companyRegController;

  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'truxoodriver',
  );

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
    } else if (widget.currentProfileImagePath != null && !widget.isLocalImage && widget.currentProfileImagePath!.startsWith('http')) {
      _networkProfileUrl = widget.currentProfileImagePath;
    }
    
    _nameController = TextEditingController(text: _clientName);
    _emailController = TextEditingController(text: _clientEmail);
    _phoneController = TextEditingController(text: _clientPhone);
    _companyNameController = TextEditingController(text: _companyName);
    _companyRegController = TextEditingController(text: _companyRegNumber);

    _fetchUserData();
  }

  // ✅ FIXED: Null-safe data fetching
  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await _firestore.collection('clients').doc(user.uid).get();
        
        if (doc.exists && mounted) {
          final rawData = doc.data();
          if (rawData == null) return;
          Map<String, dynamic> data = rawData as Map<String, dynamic>;
          
          setState(() {
            _clientName = data['fullName'] ?? _clientName;
            _clientEmail = data['email'] ?? _clientEmail;
            _clientPhone = data['phoneNumber'] ?? _clientPhone;
            _companyName = data['company'] ?? data['company_name'] ?? _companyName;
            _companyRegNumber = data['registrationNumber'] ?? data['company_reg_number'] ?? _companyRegNumber;
            
            if (data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty) {
              _networkProfileUrl = data['photoUrl'];
              _isUsingLocalImage = false;
            }

            _nameController.text = _clientName;
            _emailController.text = _clientEmail;
            _phoneController.text = _clientPhone;
            _companyNameController.text = _companyName;
            _companyRegController.text = _companyRegNumber;
            
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
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

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (_isEditingProfile || _isEditingCompany) {
      _showUnsavedChangesDialog();
      return true;
    }
    _goToHome();
    return true;
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ClientSideHome(
          displayName: _clientName,
          displayProfilePicture: _newProfileImage?.path ?? _networkProfileUrl ?? 'assets/client_imag_high.jpg',
          isUsingLocalImage: _isUsingLocalImage,
          clientEmail: _clientEmail,
          clientPhone: _clientPhone,
          companyName: _companyName,
          companyRegNumber: _companyRegNumber,
        ),
      ),
    );
  }

  void _navigateToHome() {
    if (_isEditingProfile || _isEditingCompany) {
      _showUnsavedChangesDialog();
    } else {
      _goToHome();
    }
  }
  
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image != null) {
      setState(() {
        _newProfileImage = File(image.path);
        _isUsingLocalImage = true;
      });
    }
  }

  // ✅ FIXED: Integrated Validation and Firebase Storage Upload
  Future<void> _saveProfileChanges() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Phone cannot be empty'), backgroundColor: Colors.red)
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? updatedPhotoUrl = _networkProfileUrl;

        // Upload to Storage if a new image was picked
        if (_newProfileImage != null && _isUsingLocalImage) {
          final storageRef = FirebaseStorage.instance.ref().child('client_profiles/${user.uid}.jpg');
          await storageRef.putFile(_newProfileImage!);
          updatedPhotoUrl = await storageRef.getDownloadURL();
        }

        await _firestore.collection('clients').doc(user.uid).update({
          'fullName': name,
          'phoneNumber': phone,
          'email': _emailController.text.trim(),
          if (updatedPhotoUrl != null) 'photoUrl': updatedPhotoUrl,
        });
        
        setState(() {
          _clientName = name;
          _clientPhone = phone;
          _clientEmail = _emailController.text;
          _networkProfileUrl = updatedPhotoUrl;
          _isEditingProfile = false;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _saveCompanyChanges() async {
    if (_companyNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company name cannot be empty'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('clients').doc(user.uid).update({
          'company': _companyNameController.text.trim(),
          'registrationNumber': _companyRegController.text.trim(),
        });

        setState(() {
          _companyName = _companyNameController.text;
          _companyRegNumber = _companyRegController.text;
          _isEditingCompany = false;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company details updated'), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // --- UI Components ---

  ImageProvider _getProfileImage() {
    if (_newProfileImage != null) {
      return FileImage(_newProfileImage!);
    } else if (_networkProfileUrl != null && _networkProfileUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(_networkProfileUrl!);
    } else {
      return AssetImage(_defaultProfilePicture);
    }
  }

  Future<void> _showUnsavedChangesDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('Discard changes and leave?'),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _goToHome();
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
        title: Text('My Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isLargeScreen ? 24 : 20)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _navigateToHome),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.black)) 
        : SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
              child: Column(
                children: [
                  // Profile Information Card
                  _buildProfileCard(isLargeScreen),
                  const SizedBox(height: 16),
                  // Company Details Card
                  _buildCompanyCard(isLargeScreen),
                  const SizedBox(height: 16),
                  // Dangerous Actions Card
                  _buildActionsCard(isLargeScreen),
                  const SizedBox(height: 24),
                  Text('App Version: 1.0.0', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildProfileCard(bool isLargeScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Profile Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(_isEditingProfile ? Icons.check_circle : Icons.edit, color: _isEditingProfile ? Colors.green : Colors.blue),
                  onPressed: () => _isEditingProfile ? _saveProfileChanges() : setState(() => _isEditingProfile = true),
                ),
              ],
            ),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _getProfileImage(),
                  ),
                  if (_isEditingProfile)
                    Positioned(
                      bottom: 0, right: 0,
                      child: CircleAvatar(
                        backgroundColor: Colors.blue,
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildField('Full Name', _nameController, _isEditingProfile),
            _buildField('Phone Number', _phoneController, _isEditingProfile, keyboardType: TextInputType.phone),
            _buildField('Email', _emailController, _isEditingProfile, keyboardType: TextInputType.emailAddress),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyCard(bool isLargeScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Company Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(_isEditingCompany ? Icons.check_circle : Icons.edit, color: _isEditingCompany ? Colors.green : Colors.blue),
                  onPressed: () => _isEditingCompany ? _saveCompanyChanges() : setState(() => _isEditingCompany = true),
                ),
              ],
            ),
            _buildField('Company Name', _companyNameController, _isEditingCompany),
            _buildField('Registration Number', _companyRegController, _isEditingCompany),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(bool isLargeScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: () => _showLogoutConfirmationDialog(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account'),
            onTap: () => _showDeleteAccountConfirmationDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, bool isEditing, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 4),
          isEditing 
            ? TextField(
                controller: controller,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(controller.text.isEmpty ? 'Not Provided' : controller.text),
              ),
        ],
      ),
    );
  }

  // --- Confirmation Dialogs ---

  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const OnboardingPage()), (r) => false
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountConfirmationDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text('This action is permanent. Your data will be scheduled for deletion.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await _firestore.collection('clients').doc(user.uid).update({
                  'deletionRequest': true,
                  'deletionRequestedAt': FieldValue.serverTimestamp(),
                });
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const OnboardingPage()), (r) => false
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}