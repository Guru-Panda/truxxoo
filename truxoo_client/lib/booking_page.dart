import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart'; 

// ✅ IMPORT WAITING PAGE
import 'waiting_page.dart'; 

class BookingPage extends StatefulWidget {
  final String pickupLocation;
  final String dropoffLocation;
  
  // ✅ LOGIC: Fields required for the backend flow
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  
  final String goodsType;
  final String weight;
  final String notes;
  final String clientName; 
  final String clientPhone;

  const BookingPage({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.goodsType,
    required this.weight,
    required this.notes,
    required this.clientName,
    required this.clientPhone,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  String _selectedBookingType = 'instant'; // 'instant' or 'advance'
  String? _selectedTruckType;
  late LatLng _pickupLatLng;
  late LatLng _deliveryLatLng;
  bool _locationsInitialized = false;
  bool _isBooking = false; 

  // ✅ Logic: Advance Booking Date/Time
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  @override
  void initState() {
    super.initState();
    _initializeLocations();
    BackButtonInterceptor.add(_backButtonInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    super.dispose();
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    _navigateBack();
    return true;
  }

  void _navigateBack() {
    Navigator.pop(context);
  }

  void _initializeLocations() {
    setState(() {
      _pickupLatLng = LatLng(widget.pickupLat, widget.pickupLng);
      _deliveryLatLng = LatLng(widget.dropoffLat, widget.dropoffLng);
      _locationsInitialized = true;
    });
  }

  // ✅ Logic: Date/Time Pickers for Advance
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _scheduledDate) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _scheduledTime) {
      setState(() => _scheduledTime = picked);
    }
  }

  String _generateTrackingId() {
    var rng = Random();
    return 'TRX${rng.nextInt(900000) + 100000}';
  }

  // ✅ Logic: Save to Firestore
  Future<void> _saveBookingToFirestore(String vehicleType) async {
    // 1. Validation for Advance
    if (_selectedBookingType == 'advance') {
      if (_scheduledDate == null || _scheduledTime == null) {
        // CLOSE MODAL FIRST so user can see the error
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select Date and Time for Advance Booking'), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating, // Floats above other UI
          ),
        );
        return;
      }
    }

    setState(() => _isBooking = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "User not logged in";

      FirebaseFirestore db;
      try {
        db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'truxoodriver');
      } catch (e) {
        db = FirebaseFirestore.instance;
      }

      final String trackingId = _generateTrackingId();
      
      // Determine Trip Date
      DateTime tripDateTime;
      if (_selectedBookingType == 'advance') {
        tripDateTime = DateTime(
          _scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day,
          _scheduledTime!.hour, _scheduledTime!.minute,
        );
      } else {
        tripDateTime = DateTime.now();
      }
      
      final String formattedDate = DateFormat('dd/MM/yy').format(tripDateTime);
      final String formattedTime = DateFormat('hh:mm a').format(tripDateTime);

      final Map<String, dynamic> bookingData = {
        'clientId': user.uid,
        'clientName': widget.clientName,
        'clientPhone': widget.clientPhone,
        'clientPhoto': user.photoURL ?? '',
        'status': 'pending',
        'bookingType': _selectedBookingType,
        'trackingId': trackingId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'date': formattedDate,
        'time': formattedTime,
        'scheduledTimestamp': Timestamp.fromDate(tripDateTime),
        'acceptedAt': null, 'cancelledAt': null, 'cancelledBy': null, 'deniedBy': [],
        'lockVersion': 0,
        'driverName': null, 'driverPhone': null, 'driverPhoto': null, 'truckNumber': null,
        'pickupAddress': widget.pickupLocation,
        'pickupLocation': widget.pickupLocation.split(',')[0],
        'pickupLat': widget.pickupLat, 'pickupLng': widget.pickupLng,
        'dropAddress': widget.dropoffLocation,
        'dropLocation': widget.dropoffLocation.split(',')[0],
        'dropLat': widget.dropoffLat, 'dropLng': widget.dropoffLng,
        'goodsType': widget.goodsType,
        'weight': double.tryParse(widget.weight) ?? 0.0,
        'notes': widget.notes,
        'isRoundTrip': false,
        'vehicleType': vehicleType,
        'truckType': _selectedTruckType ?? 'Standard',
        'estimatedFare': 18500,
      };

      DocumentReference docRef = await db.collection('booking_requests').add(bookingData);

      if (mounted) {
        // Close the Modal
        Navigator.pop(context); 
        
        // Navigate to Waiting Page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DriverSearchingPage(
              bookingId: docRef.id,     
              trackingId: trackingId,   
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close modal on error too
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _selectBookingType(String type) {
    setState(() => _selectedBookingType = type);
  }

  // ✅ FIXED: simplified logic to trigger modal directly
  void _selectTruckType(String truckType) {
    setState(() => _selectedTruckType = truckType);

    String title = "";
    String subtitle = "";
    String vehicleId = "";
    String imagePath = "";

    switch (truckType) {
      case 'Light Commercial Vehicle':
        title = 'Light Commercial';
        subtitle = 'Perfect for small loads';
        imagePath = 'assets/trucks/lcv_truck.png';
        vehicleId = 'LCV';
        break;
      case 'Medium Commercial Vehicle':
        title = 'Medium Commercial';
        subtitle = 'Ideal for medium cargo';
        imagePath = 'assets/trucks/mcv_truck.png';
        vehicleId = 'Medium Covered Truck';
        break;
      case 'Heavy Commercial Vehicle':
        title = 'Heavy Commercial';
        subtitle = 'Heavy duty transportation';
        imagePath = 'assets/trucks/hcv_truck.png';
        vehicleId = 'Heavy Open Truck';
        break;
      case 'Container Truck':
        title = 'Container Trucks';
        subtitle = 'Standard shipping';
        imagePath = 'assets/trucks/container_truck.png';
        vehicleId = 'Container 32ft';
        break;
      case 'Dump Truck':
        title = 'Dump Trucks';
        subtitle = 'Construction materials';
        imagePath = 'assets/trucks/dump_truck.png';
        vehicleId = 'Hyva Dump';
        break;
    }

    _showDirectModal(title, subtitle, [imagePath], vehicleId);
  }

  // ✅ FIXED: Direct Modal Opener
  void _showDirectModal(String title, String subtitle, List<String> images, String vehicleId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BaseModalSheet(
          title: title,
          subtitle: subtitle,
          images: images,
          accentColor: Colors.black,
          confirmMessage: "Confirm Booking", 
          onConfirm: () => _saveBookingToFirestore(vehicleId), // Links directly to logic
        );
      },
    );
  }

  // --- UI WIDGETS ---

  Widget _buildToggleButton(String type, String label) {
    final bool isSelected = _selectedBookingType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectBookingType(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            border: Border.all(color: Colors.black, width: 1),
            borderRadius: BorderRadius.horizontal(
              left: type == 'instant' ? const Radius.circular(8) : Radius.zero,
              right: type == 'advance' ? const Radius.circular(8) : Radius.zero,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvanceScheduler() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Schedule your trip", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Colors.black54),
                        const SizedBox(width: 8),
                        Text(
                          _scheduledDate == null ? "Select Date" : DateFormat('dd MMM').format(_scheduledDate!),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 18, color: Colors.black54),
                        const SizedBox(width: 8),
                        Text(
                          _scheduledTime == null ? "Select Time" : _scheduledTime!.format(context),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTruckItem({required String truckType, required String description, required String price, required String imagePath}) {
    final bool isSelected = _selectedTruckType == truckType;
    return GestureDetector(
      onTap: () => _selectTruckType(truckType),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black.withOpacity(0.05) : Colors.white,
          border: Border.all(color: isSelected ? Colors.black : Colors.grey.shade300, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      imagePath, width: 50, height: 50, fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.local_shipping, size: 30, color: Colors.grey.shade600),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(truckType, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ]),
                ),
                Text(price, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity, padding: const EdgeInsets.only(top: 4),
              child: Text('*This is just an approximate estimated price. The actual price may vary.', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: _navigateBack),
        title: const Text('Book a Truck', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          SizedBox(
            height: screenHeight * 0.40, // Map takes 40%
            width: double.infinity,
            child: MapWithPolyline(
              pickupLatLng: _pickupLatLng,
              deliveryLatLng: _deliveryLatLng,
              pickupLocation: widget.pickupLocation,
              dropoffLocation: widget.dropoffLocation,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [_buildToggleButton('instant', 'Instant'), _buildToggleButton('advance', 'Advance')]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        children: [
                          if (_isBooking) const LinearProgressIndicator(color: Colors.black),
                          if (_isBooking) const SizedBox(height: 10),
                          
                          // ✅ Date/Time picker shows here if Advance is selected
                          if (_selectedBookingType == 'advance') _buildAdvanceScheduler(),

                          _buildTruckItem(truckType: 'Light Commercial Vehicle', description: 'Perfect for small loads, city deliveries', price: '₹2,500', imagePath: 'assets/trucks/lcv_truck.png'),
                          _buildTruckItem(truckType: 'Medium Commercial Vehicle', description: 'Ideal for medium-sized cargo', price: '₹4,200', imagePath: 'assets/trucks/mcv_truck.png'),
                          _buildTruckItem(truckType: 'Heavy Commercial Vehicle', description: 'Heavy duty transportation', price: '₹6,800', imagePath: 'assets/trucks/hcv_truck.png'),
                          _buildTruckItem(truckType: 'Container Truck', description: 'Standard shipping containers', price: '₹8,500', imagePath: 'assets/trucks/container_truck.png'),
                          _buildTruckItem(truckType: 'Dump Truck', description: 'Construction & mining materials', price: '₹5,200', imagePath: 'assets/trucks/dump_truck.png'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== MAP WIDGET (Unchanged) ====================
class MapWithPolyline extends StatefulWidget {
  final LatLng pickupLatLng;
  final LatLng deliveryLatLng;
  final String pickupLocation;
  final String dropoffLocation;

  const MapWithPolyline({super.key, required this.pickupLatLng, required this.deliveryLatLng, required this.pickupLocation, required this.dropoffLocation});

  @override
  State<MapWithPolyline> createState() => _MapWithPolylineState();
}

class _MapWithPolylineState extends State<MapWithPolyline> {
  late GoogleMapController mapController;
  Set<Polyline> polylines = {};
  Set<Marker> markers = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  void _initializeMap() {
    markers.add(Marker(markerId: const MarkerId('pickup'), position: widget.pickupLatLng, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)));
    markers.add(Marker(markerId: const MarkerId('delivery'), position: widget.deliveryLatLng, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)));
    polylines.add(Polyline(polylineId: const PolylineId('route'), color: Colors.blue, points: [widget.pickupLatLng, widget.deliveryLatLng], width: 5));
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    Future.delayed(const Duration(milliseconds: 500), () {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(min(widget.pickupLatLng.latitude, widget.deliveryLatLng.latitude), min(widget.pickupLatLng.longitude, widget.deliveryLatLng.longitude)),
        northeast: LatLng(max(widget.pickupLatLng.latitude, widget.deliveryLatLng.latitude), max(widget.pickupLatLng.longitude, widget.deliveryLatLng.longitude)),
      );
      mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    });
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(onMapCreated: _onMapCreated, initialCameraPosition: CameraPosition(target: widget.pickupLatLng, zoom: 12), markers: markers, polylines: polylines, zoomControlsEnabled: true, myLocationButtonEnabled: false);
  }
}

// ==================== MODAL SHEET (Cleaned Up) ====================
class BaseModalSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> images;
  final String confirmMessage;
  final Color accentColor;
  final VoidCallback onConfirm;

  const BaseModalSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.images,
    required this.confirmMessage,
    required this.accentColor,
    required this.onConfirm,
  });

  @override
  State<BaseModalSheet> createState() => _BaseModalSheetState();
}

class _BaseModalSheetState extends State<BaseModalSheet> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                Text(widget.subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ])),
              GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: const Icon(Icons.close, size: 20))),
            ]),
          ),
          Expanded(
            child: Column(children: [
              Expanded(child: PageView.builder(controller: _pageController, itemCount: widget.images.length, onPageChanged: (i) => setState(() => _currentIndex = i), itemBuilder: (ctx, i) => Container(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset(widget.images[i], fit: BoxFit.cover, errorBuilder: (c,e,s)=>Icon(Icons.local_shipping, size:60, color:Colors.grey)))))),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(widget.images.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), width: _currentIndex == i ? 12 : 8, height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: _currentIndex == i ? widget.accentColor : Colors.grey.shade300))))
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(20), width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onConfirm, 
              style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, padding: const EdgeInsets.symmetric(vertical: 16)), 
              child: Text(widget.confirmMessage, style: const TextStyle(fontSize: 18, color: Colors.white))
            ),
          ),
        ],
      ),
    );
  }
}