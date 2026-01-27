import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

class OTPPage extends StatefulWidget {
  final String bookingId;
  final String trackingId;

  const OTPPage({
    super.key,
    required this.bookingId,
    required this.trackingId,
  });

  @override
  State<OTPPage> createState() => _OTPPageState();
}

class _OTPPageState extends State<OTPPage> {
  // --- LOGIC STATE VARIABLES ---
  String _pin = "....";
  bool _isLoading = true;
  
  // Data fetched from Firestore
  String? _driverName;
  String? _driverPhone;
  String? _truckNumber;
  String? _driverPhoto;
  String? _vehicleModel;
  String _pickupLocation = "Loading location...";
  String _dropoffLocation = "Loading location...";
  String _amount = "Calculating...";
  String _receiverName = "Receiver";
  String _receiverPhone = "";

  // --- UI STATE VARIABLES ---
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Start Logic
    _generateAndSavePIN();
    _fetchBookingDetails();
    
    // Add back button interceptor
    BackButtonInterceptor.add(_backButtonInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _messageController.dispose();
    super.dispose();
  }

  // --- LOGIC FUNCTIONS ---

  // 1. Handle Hardware Back Button
  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (Navigator.of(context).canPop() && ModalRoute.of(context)?.isCurrent != true) {
      return false; 
    }
    return true; 
  }

  // 2. Generate Random 4-digit PIN and save to Firestore
  Future<void> _generateAndSavePIN() async {
    var rng = Random();
    String newPin = (1000 + rng.nextInt(9000)).toString();

    if (mounted) {
      setState(() {
        _pin = newPin;
      });
    }

    try {
      FirebaseFirestore db;
      try {
        db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'truxoodriver');
      } catch (e) {
        db = FirebaseFirestore.instance;
      }

      await db.collection('booking_requests').doc(widget.bookingId).update({
        'otp': newPin,
        'status': 'otp_pending', 
      });

    } catch (e) {
      debugPrint("Error saving PIN: $e");
    }
  }

  // 3. Fetch Booking & Driver Details from Firestore
  Future<void> _fetchBookingDetails() async {
    try {
      FirebaseFirestore db;
      try {
        db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'truxoodriver');
      } catch (e) {
        db = FirebaseFirestore.instance;
      }

      DocumentSnapshot doc = await db.collection('booking_requests').doc(widget.bookingId).get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            // Driver Details
            _driverName = data['driverName'] ?? "Driver Assigning...";
            _driverPhone = data['driverPhone'];
            _truckNumber = data['truckNumber'] ?? "NO-NUM";
            _driverPhoto = data['driverPhoto'];
            _vehicleModel = data['vehicleType'] ?? "Truck";
            
            // Trip Details
            _pickupLocation = data['pickupAddress'] ?? "Pickup Location";
            _dropoffLocation = data['dropoffAddress'] ?? "Dropoff Location";
            _amount = "₹ ${data['totalAmount'] ?? '0'}";
            _receiverName = data['receiverName'] ?? "Receiver";
            _receiverPhone = data['receiverPhone'] ?? "";
            
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // 4. Call Driver
  void _callDriver() async {
    if (_driverPhone != null && _driverPhone!.isNotEmpty) {
      final Uri launchUri = Uri(scheme: 'tel', path: _driverPhone);
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not launch dialer"))
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Driver phone number not available"))
      );
    }
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Message logic not implemented yet. Sent: ${_messageController.text}')),
    );
    _messageController.clear();
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4, width: 40,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text('Cancel Trip'),
              onTap: () {
                Navigator.pop(context);
                _showCancelTripDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelTripDialog() {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Trip?'),
        content: const Text('Are you sure you want to cancel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    // Show loading until we have locations for the map
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // ===== TOP HALF: MAP (50%) =====
              SizedBox(
                height: screenHeight * 0.5,
                width: double.infinity,
                child: MapWithPolyline(
                  pickupLocation: _pickupLocation,
                  dropoffLocation: _dropoffLocation,
                ),
              ),

              // ===== BOTTOM HALF: DETAILS (50%) =====
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 40, height: 4,
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Header: Time & OTP
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'The driver is arriving soon.',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), 
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Your ride is on the way',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                            // PIN Box
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF1E88E5)),
                              ),
                              child: Column(
                                children: [
                                  const Text('PIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                  Text(
                                    _pin,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E88E5),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),

                        // Driver & Vehicle Info
                        _buildDriverSection(),

                        const SizedBox(height: 20),
                        
                        // Communication Actions
                        _buildActionButtons(),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),

                        // Locations & Receiver Info
                        _buildLocationSection(),
                        
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),

                        // Payment Info
                        _buildAmountSection(),
                        
                        // Tracking ID
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            "Tracking ID: ${widget.trackingId}",
                            style: TextStyle(color: Colors.grey[400], fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Floating Back Button
          Positioned(
            top: 40,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context), 
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverSection() {
    return Row(
      children: [
        // Avatar
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade200,
            image: (_driverPhoto != null && _driverPhoto!.isNotEmpty)
                ? DecorationImage(image: NetworkImage(_driverPhoto!), fit: BoxFit.cover)
                : null,
          ),
          child: (_driverPhoto == null || _driverPhoto!.isEmpty)
              ? Icon(Icons.person, color: Colors.grey.shade600, size: 30)
              : null,
        ),
        const SizedBox(width: 16),
        
        // Name & Vehicle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _driverName ?? "Searching...",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const Text(
                    " 4.8", // Static rating for now
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    " • ${_vehicleModel ?? 'Vehicle'}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Plate Number
        if (_truckNumber != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              _truckNumber!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(25),
            ),
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                hintText: 'Message driver...',
                prefixIcon: Icon(Icons.message_outlined, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // CALL BUTTON LINKED TO LOGIC
        InkWell(
          onTap: _callDriver,
          child: Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.call, color: Colors.green.shade700),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: _showOptionsMenu,
          child: Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.more_vert, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      children: [
        // Pickup
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 12),
                Container(height: 40, width: 2, color: Colors.grey.shade300),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Pick-up", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(
                    _pickupLocation,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),

        // Drop off
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.square, color: Colors.red, size: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Drop-off", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(
                    _dropoffLocation,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Receiver Info Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_pin, color: Colors.orange.shade800, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Receiver Details", style: TextStyle(fontSize: 11, color: Colors.brown)),
                    Text(
                      _receiverName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (_receiverPhone.isNotEmpty)
                      Text(
                        _receiverPhone,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Total Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Text(
          _amount,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ==================== REUSED MAP WIDGET ====================
class MapWithPolyline extends StatefulWidget {
  final String pickupLocation;
  final String dropoffLocation;

  const MapWithPolyline({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
  });

  @override
  State<MapWithPolyline> createState() => _MapWithPolylineState();
}

class _MapWithPolylineState extends State<MapWithPolyline> {
  late GoogleMapController mapController;
  late LatLng _pickupLatLng;
  late LatLng _deliveryLatLng;
  bool _isLoading = true;

  Set<Polyline> polylines = {};
  Set<Marker> markers = {};

  @override
  void initState() {
    super.initState();
    _initializeLocations();
  }

  Future<void> _initializeLocations() async {
    try {
      if (widget.pickupLocation.contains("Loading") || widget.dropoffLocation.contains("Loading")) {
         throw Exception("Locations not ready");
      }

      List<Location> pickupLocations = await locationFromAddress(widget.pickupLocation);
      List<Location> deliveryLocations = await locationFromAddress(widget.dropoffLocation);

      if (mounted) {
        setState(() {
          _pickupLatLng = LatLng(pickupLocations.first.latitude, pickupLocations.first.longitude);
          _deliveryLatLng = LatLng(deliveryLocations.first.latitude, deliveryLocations.first.longitude);
          _isLoading = false;
        });
        _initializeMap();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pickupLatLng = const LatLng(28.7041, 77.1025);
          _deliveryLatLng = const LatLng(28.5355, 77.3910);
          _isLoading = false;
        });
        _initializeMap();
      }
    }
  }

  void _initializeMap() {
    markers.clear();
    polylines.clear();

    markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: _pickupLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ));

    markers.add(Marker(
      markerId: const MarkerId('delivery'),
      position: _deliveryLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));

    polylines.add(Polyline(
      polylineId: const PolylineId('route'),
      color: Colors.blue,
      points: [_pickupLatLng, _deliveryLatLng],
      width: 5,
      geodesic: true,
    ));

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return GoogleMap(
      onMapCreated: (controller) {
        mapController = controller;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
             final double minLat = [_pickupLatLng.latitude, _deliveryLatLng.latitude].reduce((a, b) => a < b ? a : b);
             final double maxLat = [_pickupLatLng.latitude, _deliveryLatLng.latitude].reduce((a, b) => a > b ? a : b);
             final double minLng = [_pickupLatLng.longitude, _deliveryLatLng.longitude].reduce((a, b) => a < b ? a : b);
             final double maxLng = [_pickupLatLng.longitude, _deliveryLatLng.longitude].reduce((a, b) => a > b ? a : b);
             
             mapController.animateCamera(CameraUpdate.newLatLngBounds(
               LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
               60, // padding
             ));
          }
        });
      },
      initialCameraPosition: CameraPosition(target: _pickupLatLng, zoom: 12),
      markers: markers,
      polylines: polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }
}