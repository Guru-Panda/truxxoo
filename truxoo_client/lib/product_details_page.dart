import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for inputFormatters
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'booking_page.dart';

class ProductDetailsPage extends StatefulWidget {
  final String sourcePageType; 
  final String pickupLocation;
  final String dropoffLocation;
  
  // Coordinates
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;

  // Client Info (Sender)
  final String clientName;
  final String clientPhone;

  // Receiver & Schedule Info
  final String receiverName;
  final String receiverPhone;
  final String receiverEmail;
  final String deliveryPincode;
  final String deliveryState;
  final String pickupDate;
  final String pickupTime;
  
  const ProductDetailsPage({
    super.key,
    required this.sourcePageType,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.clientName,
    required this.clientPhone,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverEmail,
    required this.deliveryPincode,
    required this.deliveryState,
    required this.pickupDate,
    required this.pickupTime,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final TextEditingController _tonnesController = TextEditingController();
  final TextEditingController _materialInfoController = TextEditingController();
  final TextEditingController _trucksCountController = TextEditingController(text: '1'); 
  
  String? _selectedProduct;
  
  // Navigation Guard for Spam Clicks
  bool _isNavigating = false;
  
  final List<String> _productOptions = [
    'Electronics', 'Furniture', 'Food Items', 'Machinery', 'Textiles', 
    'Raw Materials', 'Chemicals', 'Automobiles', 'Construction Materials', 
    'Medical Supplies', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_backButtonInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _tonnesController.dispose();
    _materialInfoController.dispose();
    _trucksCountController.dispose(); 
    super.dispose();
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    Navigator.pop(context); 
    return true;
  }

  void _navigateBack() {
    Navigator.pop(context); 
  }

  void _submitDetails() {
    if (_isNavigating) return; // Prevent Spam Clicks
    
    FocusScope.of(context).unfocus();

    // 1. Basic Empty Validation
    if (_selectedProduct == null || 
        _tonnesController.text.trim().isEmpty || 
        _trucksCountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    } 
    
    // 2. Strict Numeric Validation
    double? weight = double.tryParse(_tonnesController.text.trim());
    int? trucks = int.tryParse(_trucksCountController.text.trim());

    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid weight greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (trucks == null || trucks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please request at least 1 truck'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Lock navigation state
    setState(() => _isNavigating = true);

    // 3. Pass everything to BookingPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingPage(
          pickupLocation: widget.pickupLocation,
          dropoffLocation: widget.dropoffLocation,
          pickupLat: widget.pickupLat,
          pickupLng: widget.pickupLng,
          dropoffLat: widget.dropoffLat,
          dropoffLng: widget.dropoffLng,
          goodsType: _selectedProduct!, 
          weight: _tonnesController.text.trim(), 
          trucksCount: trucks, // Using validated integer
          notes: _materialInfoController.text.trim(), 
          clientName: widget.clientName,
          clientPhone: widget.clientPhone,
          receiverName: widget.receiverName,
          receiverPhone: widget.receiverPhone,
          receiverEmail: widget.receiverEmail,
          deliveryPincode: widget.deliveryPincode,
          deliveryState: widget.deliveryState,
          pickupDate: widget.pickupDate,
          pickupTime: widget.pickupTime,
        ),
      ),
    ).then((_) {
      // Reset when coming back
      if (mounted) setState(() => _isNavigating = false);
    });
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
          onPressed: _navigateBack,
        ),
        title: const Text(
          'Give product details',
          style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
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
                  
                  // Product Dropdown
                  const Text('Enter Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedProduct,
                      decoration: const InputDecoration(
                        border: InputBorder.none, 
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                        hintText: 'Select a product'
                      ),
                      items: _productOptions.map((String product) {
                        return DropdownMenuItem<String>(value: product, child: Text(product));
                      }).toList(),
                      onChanged: (String? newValue) => setState(() => _selectedProduct = newValue),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Row for Weight and Truck Count
                  Row(
                    children: [
                      // Weight Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Weight (Tonnes)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _tonnesController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              // Blocks letters and forces numeric + decimal structure
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                hintText: 'Ex: 2.5',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Truck Count Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('No. of Trucks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _trucksCountController,
                              keyboardType: TextInputType.number,
                              // Strictly blocks decimals, spaces, and letters
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                hintText: 'Ex: 1',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Notes Input
                  const Text('Tell us something more about the material', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _materialInfoController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      hintText: 'Describe the material, special handling requirements...',
                    ),
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
                onPressed: _isNavigating ? null : _submitDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isNavigating 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  } 
}