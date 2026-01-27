import 'package:flutter/material.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'booking_page.dart';

class ProductDetailsPage extends StatefulWidget {
  final String sourcePageType; 
  final String pickupLocation;
  final String dropoffLocation;
  
  // ✅ Coordinates
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;

  // ✅ NEW: Receive these from previous page to pass to BookingPage
  final String clientName;
  final String clientPhone;
  
  const ProductDetailsPage({
    super.key,
    required this.sourcePageType,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    // ✅ Add these to constructor
    required this.clientName,
    required this.clientPhone,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final TextEditingController _tonnesController = TextEditingController();
  final TextEditingController _materialInfoController = TextEditingController();
  
  String? _selectedProduct;
  
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
    // 1. Validation
    if (_selectedProduct == null || _tonnesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product and enter weight'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }  
    
    // 2. Navigate to BookingPage with ALL details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingPage(
          // Location Strings
          pickupLocation: widget.pickupLocation,
          dropoffLocation: widget.dropoffLocation,
          
          // Coordinates
          pickupLat: widget.pickupLat,
          pickupLng: widget.pickupLng,
          dropoffLat: widget.dropoffLat,
          dropoffLng: widget.dropoffLng,
          
          // Product Details
          goodsType: _selectedProduct!, 
          weight: _tonnesController.text, 
          notes: _materialInfoController.text, 

          // ✅ NEW: Passing Name/Phone to BookingPage
          clientName: widget.clientName,
          clientPhone: widget.clientPhone,
        ),
      ),
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
          onPressed: _navigateBack,
        ),
        title: const Text(
          'Give product details',
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
                      decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), hintText: 'Select a product'),
                      items: _productOptions.map((String product) {
                        return DropdownMenuItem<String>(value: product, child: Text(product));
                      }).toList(),
                      onChanged: (String? newValue) => setState(() => _selectedProduct = newValue),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  const Text('Enter Tonnes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tonnesController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      hintText: 'Enter weight in tonnes',
                    ),
                  ),
                  
                  const SizedBox(height: 20),
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
                onPressed: _submitDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Submit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  } 
}