import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:intl/intl.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'product_details_page.dart';

class SenderDetailsPage extends StatefulWidget {
  final String pickupLocation;
  final String dropoffLocation;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;

  const SenderDetailsPage({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
  });

  @override
  State<SenderDetailsPage> createState() => _SenderDetailsPageState();
}

class _SenderDetailsPageState extends State<SenderDetailsPage> {
  // Sender Controllers
  final TextEditingController _senderNameController = TextEditingController();
  final TextEditingController _senderPhoneController = TextEditingController();

  // Receiver Controllers
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _receiverPhoneController = TextEditingController();
  final TextEditingController _receiverEmailController = TextEditingController();

  // Delivery Location Details
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();

  // Scheduling
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // ✅ FIX 4: Prevent Navigation Stack Spam
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_backButtonInterceptor);
    _prefillSenderData();
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _receiverEmailController.dispose();
    _pincodeController.dispose();
    _stateController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    Navigator.pop(context);
    return true;
  }

  // ✅ FIX 1: Auto-fill logic with Phone Number cleanup
  void _prefillSenderData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _senderNameController.text = user.displayName!;
      }
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        String phone = user.phoneNumber!;
        if (phone.startsWith('+91')) {
          phone = phone.substring(3); // Remove +91
        }
        _senderPhoneController.text = phone;
      }
    }
  }

  // Date Picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
        
        // Reset time if the selected date changes to today and the previously picked time is now in the past
        if (_selectedTime != null) {
          final now = DateTime.now();
          if (picked.year == now.year && picked.month == now.month && picked.day == now.day) {
            final selectedDateTime = DateTime(now.year, now.month, now.day, _selectedTime!.hour, _selectedTime!.minute);
            if (selectedDateTime.isBefore(now)) {
              _selectedTime = null;
              _timeController.clear();
            }
          }
        }
      });
    }
  }

  // Time Picker
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        final localizations = MaterialLocalizations.of(context);
        _timeController.text = localizations.formatTimeOfDay(picked, alwaysUse24HourFormat: false);
      });
    }
  }

  void _confirmDetails() {
    if (_isNavigating) return; // Prevent double-clicks
    
    FocusScope.of(context).unfocus(); 

    // 1. Mandatory Fields Validation
    if (_senderNameController.text.isEmpty ||
        _senderPhoneController.text.isEmpty ||
        _receiverNameController.text.isEmpty ||
        _receiverPhoneController.text.isEmpty ||
        _pincodeController.text.isEmpty ||
        _stateController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _timeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all mandatory fields (*)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Exact 10-digit Phone Validation
    if (_senderPhoneController.text.length != 10 || _receiverPhoneController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit phone number.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ FIX 3: Pincode Boundary Check
    if (_pincodeController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit Pincode.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ FIX 2: Past Time Selection on Current Date
    if (_selectedDate != null && _selectedTime != null) {
      final now = DateTime.now();
      if (_selectedDate!.year == now.year &&
          _selectedDate!.month == now.month &&
          _selectedDate!.day == now.day) {
        
        final selectedDateTime = DateTime(
          now.year, now.month, now.day, 
          _selectedTime!.hour, _selectedTime!.minute
        );
        
        if (selectedDateTime.isBefore(now)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a future time for today\'s pickup.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isNavigating = true);

    // 3. Navigate to ProductDetailsPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(
          sourcePageType: 'sender',
          
          // Location Data
          pickupLocation: widget.pickupLocation,
          dropoffLocation: widget.dropoffLocation,
          pickupLat: widget.pickupLat,
          pickupLng: widget.pickupLng,
          dropoffLat: widget.dropoffLat,
          dropoffLng: widget.dropoffLng,

          // Sender Info
          clientName: _senderNameController.text.trim(),
          clientPhone: _senderPhoneController.text.trim(),

          // Receiver & Delivery Info
          receiverName: _receiverNameController.text.trim(),
          receiverPhone: _receiverPhoneController.text.trim(),
          receiverEmail: _receiverEmailController.text.trim(),
          deliveryPincode: _pincodeController.text.trim(),
          deliveryState: _stateController.text.trim(),
          
          // Scheduling
          pickupDate: _dateController.text.trim(),
          pickupTime: _timeController.text.trim(),
        ),
      ),
    ).then((_) {
      // Reset navigation state when coming back
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // 1. SENDER INFORMATION
                  _buildSectionTitle('Sender Information'),
                  const SizedBox(height: 15),
                  _buildInputField(label: 'Sender Name *', controller: _senderNameController),
                  const SizedBox(height: 15),
                  _buildInputField(
                    label: 'Sender Phone *', 
                    controller: _senderPhoneController, 
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),

                  const SizedBox(height: 30),

                  // 2. RECEIVER INFORMATION
                  _buildSectionTitle('Receiver Information'),
                  const SizedBox(height: 15),
                  _buildInputField(label: 'Receiver Name *', controller: _receiverNameController),
                  const SizedBox(height: 15),
                  _buildInputField(
                    label: 'Receiver Phone *', 
                    controller: _receiverPhoneController, 
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 15),
                  _buildInputField(label: 'Receiver Email ID', controller: _receiverEmailController, keyboardType: TextInputType.emailAddress, isOptional: true),

                  const SizedBox(height: 30),

                  // 3. DELIVERY LOCATION DETAILS
                  _buildSectionTitle('Delivery Location'),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          label: 'Pincode *', 
                          controller: _pincodeController, 
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        )
                      ),
                      const SizedBox(width: 15),
                      Expanded(child: _buildInputField(label: 'State *', controller: _stateController)),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 4. SCHEDULE
                  _buildSectionTitle('When do you need the truck?'),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(context),
                          child: AbsorbPointer(
                            child: _buildInputField(
                              label: 'Pickup Date *',
                              controller: _dateController,
                              suffixIcon: Icons.calendar_today,
                              hint: 'dd-mm-yyyy',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectTime(context),
                          child: AbsorbPointer(
                            child: _buildInputField(
                              label: 'Pickup Time *',
                              controller: _timeController,
                              suffixIcon: Icons.access_time,
                              hint: '--:--',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // CONFIRM BUTTON
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isNavigating ? null : _confirmDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isNavigating 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool isOptional = false,
    IconData? suffixIcon,
    String? hint,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.replaceAll('*', ''),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
            if (label.contains('*'))
              const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            if (isOptional)
              const Text(' (Optional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: suffixIcon != null,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            counterText: "", 
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.grey) : null,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}