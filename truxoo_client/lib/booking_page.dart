import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart'; 
import 'package:geocoding/geocoding.dart'; 

class BookingPage extends StatefulWidget {
  final String pickupLocation;
  final String dropoffLocation;
  
  // Location Coordinates
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  
  // Product Details
  final String goodsType;
  final String weight;
  final int trucksCount; 
  final String notes;

  // Client (Sender) Details
  final String clientName; 
  final String clientPhone;

  // Receiver Details
  final String receiverName;
  final String receiverPhone;
  final String receiverEmail;
  final String deliveryPincode;
  final String deliveryState; 

  // User Requested Schedule 
  final String pickupDate;
  final String pickupTime;

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
    required this.trucksCount, 
    required this.notes,
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
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  String _selectedBookingType = 'instant'; // 'instant' or 'advance'
  String? _selectedTruckType;
  late LatLng _pickupLatLng;
  late LatLng _deliveryLatLng;
  bool _isBooking = false; 
  bool _isLoadingRates = true; 

  // Dynamic Pricing Variables
  String _pickupStateName = '';
  String _deliveryStateName = '';
  bool _isSameState = false;
  Map<String, int> _calculatedRates = {};

  @override
  void initState() {
    super.initState();
    _initializeLocations();
    _fetchStatesAndCalculateRates(); 
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
      _deliveryStateName = widget.deliveryState; // Fallback
    });
  }

  // --- REVERSE GEOCODING & DYNAMIC PRICING LOGIC ---

  Future<void> _fetchStatesAndCalculateRates() async {
    try {
      // 1. Fetch Pickup State using Lat/Lng
      List<Placemark> pickupPlacemarks = await placemarkFromCoordinates(widget.pickupLat, widget.pickupLng);
      if (pickupPlacemarks.isNotEmpty) {
        _pickupStateName = pickupPlacemarks.first.administrativeArea ?? '';
      }

      // 2. Fetch Delivery State using Lat/Lng
      List<Placemark> dropoffPlacemarks = await placemarkFromCoordinates(widget.dropoffLat, widget.dropoffLng);
      if (dropoffPlacemarks.isNotEmpty) {
        _deliveryStateName = dropoffPlacemarks.first.administrativeArea ?? widget.deliveryState;
      }
    } catch (e) {
      debugPrint("Geocoding failed, falling back to basic data: $e");
    }

    _calculateDynamicRates();
  }

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; 
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 + 
              cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    double straightDistance = 12742 * asin(sqrt(a)); 
    return straightDistance * 1.35; 
  }

  void _calculateDynamicRates() {
    double dist = _calculateDistanceKm(widget.pickupLat, widget.pickupLng, widget.dropoffLat, widget.dropoffLng);
    double w = double.tryParse(widget.weight) ?? 1.0;
    
    // Geocoding Fallback to prevent massive price spikes
    bool isSameState = false;
    if (_pickupStateName.isNotEmpty && _deliveryStateName.isNotEmpty) {
      isSameState = _pickupStateName.trim().toLowerCase() == _deliveryStateName.trim().toLowerCase();
    } else {
      isSameState = dist < 50.0; // Assume intrastate if API failed but distance is short
    }

    int scvRate = (24.5 * dist * w).round();
    int lcvRate = ((dist <= 60 ? 24.5 : 22.5) * dist * w).round();

    double mcv = 0;
    if (isSameState) {
      if (dist <= 100) mcv = 7.8 * dist * w;
      else if (dist <= 300) mcv = 7.2 * dist * w;
      else if (dist <= 600) mcv = 6.8 * dist * w;
      else mcv = 6.4 * dist * w;
      if (mcv < 6000) mcv = 6000;
    } else {
      if (dist <= 300) mcv = 18.9 * dist * w;
      else if (dist <= 600) mcv = 16.0 * dist * w;
      else if (dist <= 1200) mcv = 14.5 * dist * w;
      else if (dist <= 1300) mcv = 13.6 * dist * w;
      else mcv = 12.0 * dist * w;
      if (mcv < 12500) mcv = 12500;
    }

    double hcv = 0;
    if (isSameState) {
      if (dist <= 100) hcv = 6.9 * dist * w;
      else if (dist <= 300) hcv = 6.4 * dist * w;
      else if (dist <= 600) hcv = 6.2 * dist * w;
      else hcv = 5.8 * dist * w;
      if (hcv < 9000) hcv = 9000;
    } else {
      if (dist <= 300) hcv = 16.0 * dist * w;
      else if (dist <= 600) hcv = 13.5 * dist * w;
      else if (dist <= 1200) hcv = 13.0 * dist * w;
      else hcv = 11.0 * dist * w;
      if (hcv < 20000) hcv = 20000;
    }

    setState(() {
      _isSameState = isSameState;
      _isLoadingRates = false; 
      _calculatedRates = {
        'Small Commercial Vehicle': scvRate,
        'Light Commercial Vehicle': lcvRate,
        'Medium Commercial Vehicle': mcv.round(),
        'Heavy Commercial Vehicle': hcv.round(),
        'Container Truck': (hcv * 1.1).round(), 
        'Dump Truck': (hcv * 1.05).round(),
      };
    });
  }

  String _generateTrackingId() {
    var rng = Random();
    return 'TRX${rng.nextInt(900000) + 100000}';
  }

  Future<void> _saveBookingToFirestore(String vehicleType) async {
    if (_isBooking) return; 

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
      
      // Accurately parse the user's requested date and time
      DateTime scheduledDateTime;
      try {
        scheduledDateTime = DateFormat('dd-MM-yyyy hh:mm a')
            .parse('${widget.pickupDate} ${widget.pickupTime}');
      } catch (e) {
        scheduledDateTime = DateTime.now(); 
      }
      
      final String formattedDate = DateFormat('dd/MM/yy').format(scheduledDateTime);
      final String formattedTime = DateFormat('hh:mm a').format(scheduledDateTime);

      int estimatedFare = _calculatedRates[_selectedTruckType ?? 'Heavy Commercial Vehicle'] ?? 0;

      final Map<String, dynamic> bookingData = {
        'clientId': user.uid,
        'clientName': widget.clientName,
        'clientPhone': widget.clientPhone,
        'clientPhoto': user.photoURL ?? '',
        
        'receiverName': widget.receiverName,
        'receiverPhone': widget.receiverPhone,
        'receiverEmail': widget.receiverEmail,
        'deliveryPincode': widget.deliveryPincode,
        'deliveryState': _deliveryStateName,
        'pickupState': _pickupStateName, 
        'requestedDate': widget.pickupDate, 
        'requestedTime': widget.pickupTime, 

        'status': 'pending',
        'bookingType': _selectedBookingType,
        'trackingId': trackingId,
        
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        
        'date': formattedDate, 
        'time': formattedTime, 
        'scheduledTimestamp': Timestamp.fromDate(scheduledDateTime), 
        
        'pickupAddress': widget.pickupLocation,
        'pickupLocation': widget.pickupLocation.split(',')[0],
        'pickupLat': widget.pickupLat, 'pickupLng': widget.pickupLng,
        'dropAddress': widget.dropoffLocation,
        'dropLocation': widget.dropoffLocation.split(',')[0],
        'dropLat': widget.dropoffLat, 'dropLng': widget.dropoffLng,
        
        'goodsType': widget.goodsType,
        'weight': double.tryParse(widget.weight) ?? 0.0,
        'trucksCount': widget.trucksCount, 
        'notes': widget.notes,
        
        'vehicleType': vehicleType,
        'truckType': _selectedTruckType ?? 'Standard',
        'estimatedFare': estimatedFare, 
        
        'acceptedAt': null, 'cancelledAt': null, 'cancelledBy': null, 'deniedBy': [],
        'lockVersion': 0,
        'driverName': null, 'driverPhone': null, 'driverPhoto': null, 'truckNumber': null,
        'isRoundTrip': false,
      };

      await db.collection('booking_requests').add(bookingData);

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking Confirmed! ID: $trackingId'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _selectBookingType(String type) {
    setState(() => _selectedBookingType = type);
  }

  void _selectTruckType(String truckType) {
    setState(() => _selectedTruckType = truckType);

    String title = "";
    String subtitle = "";
    String vehicleId = "";
    List<String> imagePaths = []; 

    switch (truckType) {
      case 'Small Commercial Vehicle':
        title = 'Small Commercial';
        subtitle = 'Ideal for local narrow streets';
        vehicleId = 'SCV';
        imagePaths = ['assets/scv1.png', 'assets/scv2.png', 'assets/scv3.png'];
        break;
      case 'Light Commercial Vehicle':
        title = 'Light Commercial';
        subtitle = 'Perfect for small loads';
        vehicleId = 'LCV';
        imagePaths = ['assets/lcv1.png', 'assets/lcv2.png', 'assets/lcv3.png'];
        break;
      case 'Medium Commercial Vehicle':
        title = 'Medium Commercial';
        subtitle = 'Ideal for medium cargo';
        vehicleId = 'Medium Covered Truck';
        imagePaths = ['assets/mcv1.png', 'assets/mcv2.png', 'assets/mcv3.png'];
        break;
      case 'Heavy Commercial Vehicle':
        title = 'Heavy Commercial';
        subtitle = 'Heavy duty transportation';
        vehicleId = 'Heavy Open Truck';
        imagePaths = ['assets/hcv1.png', 'assets/hcv2.png', 'assets/hcv3.png'];
        break;
      case 'Container Truck':
        title = 'Container Trucks';
        subtitle = 'Standard shipping';
        vehicleId = 'Container 32ft';
        imagePaths = ['assets/container1.png', 'assets/container2.png', 'assets/container3.png'];
        break;
      case 'Dump Truck':
        title = 'Dump Trucks';
        subtitle = 'Construction materials';
        vehicleId = 'Hyva Dump';
        imagePaths = ['assets/dump1.png', 'assets/dump2.png', 'assets/dump3.png'];
        break;
    }

    _showDirectModal(title, subtitle, imagePaths, vehicleId);
  }

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
          onConfirm: () async => await _saveBookingToFirestore(vehicleId), 
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

  // ✅ Restored the "Advance" placeholder message
  Widget _buildAdvanceNotice() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          Icon(Icons.access_time_filled, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            "No returning trucks available in your area right now check back later.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTruckItem({required String truckType, required String description, required String imagePath}) {
    if (truckType == 'Small Commercial Vehicle' && !_isSameState) {
      return const SizedBox.shrink();
    }

    int rate = _calculatedRates[truckType] ?? 0;
    String formattedPrice = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(rate);

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Starting from', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(formattedPrice, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
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
            height: screenHeight * 0.40, 
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
                  child: _isLoadingRates 
                  ? const Center(child: CircularProgressIndicator(color: Colors.black)) 
                  : SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        children: [
                          if (_isBooking) const LinearProgressIndicator(color: Colors.black),
                          if (_isBooking) const SizedBox(height: 10),
                          
                          // ✅ Toggles correctly based on user intent
                          if (_selectedBookingType == 'advance') 
                            _buildAdvanceNotice()
                          else ...[
                            _buildTruckItem(truckType: 'Small Commercial Vehicle', description: '0.5 - 1 Ton, Local narrow streets', imagePath: 'assets/trucks/scv_truck.png'),
                            _buildTruckItem(truckType: 'Light Commercial Vehicle', description: '1 - 5 Ton, Commercial goods', imagePath: 'assets/trucks/lcv_truck.png'),
                            _buildTruckItem(truckType: 'Medium Commercial Vehicle', description: '6 - 14 Ton, Mid-sized industrial shipments', imagePath: 'assets/trucks/mcv_truck.png'),
                            _buildTruckItem(truckType: 'Heavy Commercial Vehicle', description: '14 - 24+ Ton, Heavy duty bulk cargo', imagePath: 'assets/trucks/hcv_truck.png'),
                            _buildTruckItem(truckType: 'Container Truck', description: 'Standard shipping containers', imagePath: 'assets/trucks/container_truck.png'),
                            _buildTruckItem(truckType: 'Dump Truck', description: 'Construction & mining materials', imagePath: 'assets/trucks/dump_truck.png'),
                          ]
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

// ==================== MAP WIDGET ====================
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

// ==================== MODAL SHEET ====================
class BaseModalSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> images;
  final String confirmMessage;
  final Color accentColor;
  final Future<void> Function() onConfirm; 

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
  bool _isConfirming = false; 

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
              onPressed: _isConfirming ? null : () async {
                setState(() => _isConfirming = true);
                await widget.onConfirm();
                if (mounted) setState(() => _isConfirming = false);
              }, 
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accentColor, 
                disabledBackgroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 16)
              ), 
              child: _isConfirming 
                ? const SizedBox(
                    height: 20, 
                    width: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : Text(widget.confirmMessage, style: const TextStyle(fontSize: 18, color: Colors.white))
            ),
          ),
        ],
      ),
    );
  }
}