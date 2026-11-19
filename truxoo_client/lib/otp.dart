import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

// INTERNAL IMPORTS
import 'services/chat_screen.dart'; // ✅ Just importing the screen now

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
  String _status = 'pending'; 
  
  // Stream Subscription to listen for database changes
  StreamSubscription<DocumentSnapshot>? _bookingSubscription;

  // Data fetched from Firestore
  Map<String, dynamic>? _bookingData; 
  String? _driverName;
  String? _driverPhone;
  String? _truckNumber;
  String? _driverPhoto;
  String? _vehicleModel;
  
  String _pickupLocation = "Loading location...";
  String _dropoffLocation = "Loading location...";
  
  double? _pickupLat;
  double? _pickupLng;
  double? _dropoffLat;
  double? _dropoffLng;

  String _amount = "Calculating...";
  String _receiverName = "Receiver";
  String _receiverPhone = "";

  @override
  void initState() {
    super.initState();
    _listenToBookingDetails(); 
    BackButtonInterceptor.add(_backButtonInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    // Cancel the listener to prevent memory leaks when switching between rides
    _bookingSubscription?.cancel();
    super.dispose();
  }

  // Handle Hardware Back Button -> Go to Home
  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    return true; 
  }

  void _listenToBookingDetails() {
    try {
      FirebaseFirestore db;
      try {
        db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'truxoodriver');
      } catch (e) {
        db = FirebaseFirestore.instance;
      }

      _bookingSubscription = db
          .collection('booking_requests')
          .doc(widget.bookingId)
          .snapshots()
          .listen((DocumentSnapshot doc) {
        
        if (doc.exists && mounted) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          String currentStatus = data['status'] ?? 'pending';
          if (currentStatus == 'completed' || currentStatus == 'cancelled' || currentStatus == 'denied') {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("This ride is now $currentStatus."), backgroundColor: Colors.blueGrey)
             );
             Navigator.of(context).popUntil((route) => route.isFirst);
             return; 
          }

          setState(() {
            _bookingData = data; 
            _status = currentStatus;
            
            // Extract OTP
            _pin = data['otp'] ?? "...."; 
            
            // Driver Details
            _driverName = data['driverName'] ?? "Driver Assigning...";
            _driverPhone = data['driverPhone'];
            _truckNumber = data['truckNumber'] ?? "NO-NUM";
            _driverPhoto = data['driverPhoto'];
            _vehicleModel = data['vehicleType'] ?? "Truck";
            
            // Location Text
            _pickupLocation = data['pickupAddress'] ?? "Pickup Location";
            _dropoffLocation = data['dropAddress'] ?? "Dropoff Location"; 
            
            // Extract Exact Coordinates
            _pickupLat = data['pickupLat'];
            _pickupLng = data['pickupLng'];
            _dropoffLat = data['dropLat'];
            _dropoffLng = data['dropLng'];
            
            // Pricing
            if (data['finalPrice'] != null) {
              _amount = "₹ ${data['finalPrice']}";
            } else {
              _amount = "₹ ${data['estimatedFare'] ?? '0'} (Est)";
            }
            
            // Receiver
            _receiverName = data['receiverName'] ?? "Receiver";
            _receiverPhone = data['receiverPhone'] ?? "";
            
            _isLoading = false;
          });
        }
      }, onError: (e) {
        debugPrint("Error listening to details: $e");
        if(mounted) setState(() => _isLoading = false);
      });

    } catch (e) {
      debugPrint("Error setting up stream: $e");
    }
  }

  void _callDriver() async {
    String? phoneToCall = _driverPhone;

    // Route the phone call to the Fleet Owner if it's an agency ride
    if (_bookingData != null && _bookingData!['assignedByOwner'] != null && _bookingData!['owner_ph'] != null) {
      phoneToCall = _bookingData!['owner_ph'];
    }

    if (phoneToCall != null && phoneToCall.isNotEmpty) {
      final Uri launchUri = Uri(scheme: 'tel', path: phoneToCall);
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
        const SnackBar(content: Text("Phone number not available"))
      );
    }
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
              leading: Icon(Icons.cancel, color: _status == 'pending' ? Colors.red : Colors.grey),
              title: Text('Cancel Trip', style: TextStyle(color: _status == 'pending' ? Colors.red : Colors.grey)),
              onTap: () {
                Navigator.pop(context); 
                
                if (_status == 'pending') {
                  _showCancelTripDialog(); 
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Cannot cancel ride after driver is assigned. Please call support."),
                      backgroundColor: Colors.orange,
                    )
                  );
                }
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
            onPressed: () async {
              Navigator.pop(context); 
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Cancelling ride..."))
              );

              try {
                FirebaseFirestore db;
                try {
                  db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'truxoodriver');
                } catch (e) {
                  db = FirebaseFirestore.instance;
                }

                await db.collection('booking_requests').doc(widget.bookingId).update({
                  'status': 'cancelled',
                  'cancelledBy': 'client',
                  'cancelledAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Ride cancelled successfully."))
                  );
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to cancel: $e"))
                  );
                }
              }
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

    if (_isLoading || _pickupLat == null || _dropoffLat == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
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
                  pickupLat: _pickupLat!,
                  pickupLng: _pickupLng!,
                  dropoffLat: _dropoffLat!,
                  dropoffLng: _dropoffLng!,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'The driver is arriving soon.',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Your ride is on the way',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
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
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), 
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                "• ${_vehicleModel ?? 'Vehicle'}",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        
        // Plate Number
        if (_truckNumber != null) ...[
          const SizedBox(width: 8),
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
        ]
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // ====== CHAT BUTTON ======
        Expanded(
          child: InkWell(
            onTap: () {
              // ✅ FIX: Now directly opens the static ChatScreen without passing old parameters
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatScreen()),
              );
            },
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Icon(Icons.message_outlined, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Message...',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        
        // CALL BUTTON
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
        
        // OPTIONS BUTTON
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_receiverPhone.isNotEmpty)
                      Text(
                        _receiverPhone,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Total Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12), 
        Expanded(
          child: Text(
            _amount,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ==================== FAST MAP WIDGET ====================
class MapWithPolyline extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;

  const MapWithPolyline({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
  });

  @override
  State<MapWithPolyline> createState() => _MapWithPolylineState();
}

class _MapWithPolylineState extends State<MapWithPolyline> {
  late GoogleMapController mapController;
  late LatLng _pickupLatLng;
  late LatLng _deliveryLatLng;

  Set<Polyline> polylines = {};
  Set<Marker> markers = {};

  @override
  void initState() {
    super.initState();
    _pickupLatLng = LatLng(widget.pickupLat, widget.pickupLng);
    _deliveryLatLng = LatLng(widget.dropoffLat, widget.dropoffLng);
    _initializeMap();
  }

  void _initializeMap() {
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
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: (controller) {
        mapController = controller;
        Future.delayed(const Duration(milliseconds: 300), () {
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