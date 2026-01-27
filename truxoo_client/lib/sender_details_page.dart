import 'package:flutter/material.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'product_details_page.dart';

class SenderDetailsPage extends StatefulWidget {
  final String pickupLocation;
  final String dropoffLocation;
  
  // ✅ Added Coordinates
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;

  const SenderDetailsPage({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
    // ✅ Receive coordinates from UserSelectionPage
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
  });

  @override
  State<SenderDetailsPage> createState() => _SenderDetailsPageState();
}

class _SenderDetailsPageState extends State<SenderDetailsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _landmarksController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_backButtonInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _landmarksController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    Navigator.pop(context); 
    return true;
  }

  void _navigateBackToUserSelection() {
    Navigator.pop(context); 
  }

  void _confirmDetails() {
    if (_nameController.text.isEmpty || 
        _phoneController.text.isEmpty ||
        _stateController.text.isEmpty ||
        _pincodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ Navigate to ProductDetailsPage with coordinates AND Name/Phone
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(
          sourcePageType: 'sender',
          pickupLocation: widget.pickupLocation,
          dropoffLocation: widget.dropoffLocation,
          
          // ✅ Passing coordinates forward
          pickupLat: widget.pickupLat,
          pickupLng: widget.pickupLng,
          dropoffLat: widget.dropoffLat,
          dropoffLng: widget.dropoffLng,
          
          // ✅ NEW: Passing Name and Phone to ProductDetailsPage
          // This ensures it eventually reaches BookingPage & Firestore
          clientName: _nameController.text.trim(),
          clientPhone: _phoneController.text.trim(),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            if (isOptional)
              const Text(
                ' (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _navigateBackToUserSelection,
        ),
        title: const Text(
          'Enter sender details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  
                  _buildInputField(
                    label: 'Name',
                    controller: _nameController,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildInputField(
                    label: 'Phone no',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildInputField(
                    label: 'Email ID',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    isOptional: true,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildInputField(
                    label: 'Any nearby landmarks',
                    controller: _landmarksController,
                    maxLines: 2,
                    isOptional: true,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildInputField(
                    label: 'State',
                    controller: _stateController,
                    isOptional: false,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildInputField(
                    label: 'Pincode',
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    isOptional: false,
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}