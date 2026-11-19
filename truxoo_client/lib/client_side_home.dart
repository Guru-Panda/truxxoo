import 'package:flutter/material.dart';
import 'package:truxoo_client_new/onboarding_page.dart';
import 'package:truxoo_client_new/track_truck.dart';
import 'package:truxoo_client_new/location_selection_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:truxoo_client_new/client_history.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/services.dart';
import 'client_side_my_accounts.dart';
// 1. Firebase Imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:cached_network_image/cached_network_image.dart';

// ✅ IMPORT OTP PAGE
import 'otp.dart'; 

// Colors
const Color kPrimaryColor = Colors.black;
const Color kAccentColor = Color(0xFF6BF15E);
const Color kBackgroundColor = Color(0xFFF8F9FD);

class ClientSideHome extends StatefulWidget {
  final String displayName;
  final String displayProfilePicture;
  final bool isUsingLocalImage;
  final String clientPhone;
  final String clientEmail;
  final String companyName;
  final String companyRegNumber;

  const ClientSideHome({
    super.key,
    this.displayName = 'Guest User',
    this.displayProfilePicture = 'assets/client_imag_high.jpg',
    this.isUsingLocalImage = false,
    this.clientPhone = "",
    this.clientEmail = "",
    this.companyName = "",
    this.companyRegNumber = "",
  });

  @override
  State<ClientSideHome> createState() => _ClientSideHomeState();
}

class _ClientSideHomeState extends State<ClientSideHome> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  DateTime? _lastBackPressTime;
  
  late bool _isUsingLocalImage;
  bool _isUsingNetworkImage = false; 
  late String _displayProfilePicture;
  late String _displayName;
  late String _clientPhone;
  late String _clientEmail;
  late String _companyName;
  late String _companyRegNumber;
  
  final PageController _pageController = PageController(viewportFraction: 0.90);
  bool _hasLocationPermission = false;

  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'truxoodriver', 
  );

  @override
  void initState() {
    super.initState();
    _displayName = widget.displayName;
    _displayProfilePicture = widget.displayProfilePicture;
    _isUsingLocalImage = widget.isUsingLocalImage;
    _clientPhone = widget.clientPhone;
    _clientEmail = widget.clientEmail;
    _companyName = widget.companyName;
    _companyRegNumber = widget.companyRegNumber;
    
    BackButtonInterceptor.add(_backButtonInterceptor);
    _fetchClientDetails(); 

    // ✅ FIXED: Wait for transition, then start the smart location flow
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _checkAndRequestLocation();
      }
    });
  }

  Future<void> _fetchClientDetails() async {
    try {
      final User? currentUser;
      try {
        currentUser = FirebaseAuth.instance.currentUser;
      } catch (authError) {
        debugPrint("Firebase Auth Error: $authError");
        return; 
      }

      if (currentUser != null) {
        DocumentSnapshot clientDoc = await _firestore
            .collection('clients')
            .doc(currentUser.uid)
            .get();

        if (clientDoc.exists && mounted) {
          final data = clientDoc.data() as Map<String, dynamic>;

          setState(() {
            if (data.containsKey('fullName') && data['fullName'] != null) {
              _displayName = data['fullName'];
            }
            if (data.containsKey('email') && data['email'] != null) {
              _clientEmail = data['email'];
            }
            if (data.containsKey('phoneNumber')) {
               _clientPhone = data['phoneNumber'];
            }
            if (data.containsKey('photoUrl') && 
                data['photoUrl'] != null && 
                data['photoUrl'].toString().isNotEmpty) {
              _displayProfilePicture = data['photoUrl'];
              _isUsingNetworkImage = true;
              _isUsingLocalImage = false;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Critical Error fetching client details: $e");
    }
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildProfileImage({double size = 50}) {
    if (_isUsingNetworkImage) {
      return CachedNetworkImage(
        imageUrl: _displayProfilePicture,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[200]),
        errorWidget: (context, url, error) => Image.asset('assets/client_imag_high.jpg', width: size, height: size, fit: BoxFit.cover),
      );
    } else if (_isUsingLocalImage) {
      return Image.file(File(_displayProfilePicture), width: size, height: size, fit: BoxFit.cover);
    } else {
      return Image.asset(_displayProfilePicture, width: size, height: size, fit: BoxFit.cover);
    }
  }

  // ==================== NEW SMART LOCATION FLOW ====================

  Future<void> _checkAndRequestLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { 
        _showLocationServiceDialog(); 
        return; 
      }
      
      // 1. Silently check if permission is already granted
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        if (mounted) setState(() => _hasLocationPermission = true);
        return;
      }
      
      // 2. If denied, show our friendly soft prompt first!
      if (permission == LocationPermission.denied) {
        if (mounted) _showLocationSoftPrompt();
      } else if (permission == LocationPermission.deniedForever) {
        if (mounted) _showPermanentlyDeniedDialog(); 
      }
    } catch (e) { 
      print('Error checking location permission: $e'); 
    }
  }

  void _showLocationSoftPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.black, size: 28),
            SizedBox(width: 10),
            Text('Location Access', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Unload needs access to your location to help you find nearby trucks, provide accurate live tracking, and ensure smooth logistics management.\n\nPlease allow location access on the next screen to get the best experience.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // User said no to the soft prompt
            },
            child: const Text('Not Now', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); 
              _requestSystemLocationPermission(); // User agreed, trigger the real system pop-up!
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Allow', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _requestSystemLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        if (mounted) _showPermanentlyDeniedDialog();
        return;
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        if (mounted) setState(() => _hasLocationPermission = true);
      }
    } catch (e) {
      print('Error requesting system location permission: $e');
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text('Please enable location services in your phone settings to use tracking features.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Colors.black)))],
      ),
    );
  }
  
  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Denied'),
        content: const Text('Location permission is permanently denied. Please open your phone settings, go to Truxoo, and enable location access.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Colors.black)))],
      ),
    );
  }

  // ==================== NAVIGATION ====================

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    switch (index) {
      case 1: _navigateToHistory(); break;
      case 2: _navigateToMyAccount(); break; 
    }
  }

  void _handleDrawerNavigation(VoidCallback navigateFunction) {
    _scaffoldKey.currentState?.closeDrawer(); 
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        navigateFunction(); 
      }
    });
  }

  void _navigateToMyAccount() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => MyAccountClient(
      currentProfileImagePath: _displayProfilePicture,
      isLocalImage: _isUsingLocalImage, 
      clientName: _displayName,
      clientPhone: _clientPhone,
      clientEmail: _clientEmail,
      companyName: _companyName,
      companyRegNumber: _companyRegNumber,
    ))).then((_) {
      if (mounted) { setState(() => _selectedIndex = 0); _fetchClientDetails(); }
    });
  }

  void _navigateToHistory() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ClientHistory(
      displayName: _displayName, 
      displayProfilePicture: _displayProfilePicture, 
      isUsingLocalImage: _isUsingLocalImage
    ))).then((_) { 
      if (mounted) setState(() => _selectedIndex = 0); 
    });
  }

  void _navigateToTrackTruck() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => TrackTruck(
      displayName: _displayName, 
      displayProfilePicture: _displayProfilePicture, 
      isUsingLocalImage: _isUsingLocalImage
    )));
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) { 
      _scaffoldKey.currentState?.closeDrawer(); 
      return true; 
    }
    if (_selectedIndex != 0) { setState(() => _selectedIndex = 0); return true; }
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Press back again to exit'), duration: Duration(seconds: 2)));
      return true;
    }
    SystemNavigator.pop();
    return true;
  }

  Future<void> _launchUrl(String url, String title) async {
    final Uri uri = Uri.parse(url);
    try { 
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw 'Could not launch'; 
    } catch (e) { 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error launching $title'))); 
    }
  }

  Future<void> _cancelRide(String bookingId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Ride?"),
        content: const Text("Are you sure you want to cancel this booking?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await _firestore.collection('booking_requests').doc(bookingId).update({
        'status': 'cancelled',
        'cancelledBy': 'client',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride Cancelled")));
    }
  }

  Widget _buildActiveBookingSection() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('booking_requests')
          .where('clientId', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'accepted', 'assigned', 'otp_pending', 'in_progress']) 
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink(); 

        final docs = snapshot.data!.docs;

        return Container(
          height: 160, 
          margin: const EdgeInsets.only(bottom: 20),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String status = data['status'];
              String bookingId = doc.id;
              String trackingId = data['trackingId'] ?? 'N/A';
              String pickup = data['pickupLocation'] ?? 'Unknown';
              String drop = data['dropLocation'] ?? 'Unknown';

              return Container(
                width: MediaQuery.of(context).size.width * 0.82,
                margin: const EdgeInsets.only(right: 16, bottom: 10, left: 2), 
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kAccentColor.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: kAccentColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (status != 'pending') {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => OTPPage(bookingId: bookingId, trackingId: trackingId))
                            );
                          }
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Searching for your load... Please wait.")));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: kAccentColor, borderRadius: BorderRadius.circular(20)),
                                child: Text(status == 'pending' ? 'SEARCHING' : 'ONGOING RIDE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                              ),
                              IconButton(onPressed: () => _cancelRide(bookingId), icon: const Icon(Icons.close, color: Colors.red, size: 22)),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 28, color: Colors.black87),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("$pickup ➝ $drop", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text("ID: $trackingId", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double headerHeight = 110.0; 

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kBackgroundColor,
      drawer: _buildDrawer(), 
      // Updated with Font Awesome Icon
      floatingActionButton: FloatingActionButton(
        onPressed: _launchWhatsApp,
        backgroundColor: const Color(0xFF25D366), // Official WhatsApp Green
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: const FaIcon(
          FontAwesomeIcons.whatsapp, 
          color: Colors.white, 
          size: 28,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: headerHeight + 25), 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Services', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 145,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: const [
                            ModernServiceCard(image: 'assets/logistics.jpg', title: 'Logistics Management'),
                            ModernServiceCard(image: 'assets/pre-booking.webp', title: 'Pre-booking'),
                            ModernServiceCard(image: 'assets/live-tracking.jpg', title: 'Live Tracking'),
                            ModernServiceCard(image: 'assets/24seven.jpg', title: '24/7 Support'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _navigateToTrackTruck,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                                        child: const Icon(Icons.gps_fixed, color: kAccentColor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Track Shipment', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildActiveBookingSection(),
                      const Text('Highlights', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 170,
                        child: PageView(
                          controller: _pageController,
                          children: const [
                            PromoImage(image: 'assets/client_imag_high.jpg'),
                            PromoImage(image: 'assets/poster1.jpeg'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text('Benefits', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 220,
                        child: PageView(
                          controller: PageController(viewportFraction: 0.90),
                          children: const [
                            BenefitCard(image: 'assets/poster3.jpeg', title: 'Live Tracking'),
                            BenefitCard(image: 'assets/poster4.jpeg', title: 'Logistics Digitalized'),
                            BenefitCard(image: 'assets/poster6.jpeg', title: 'Connecting India'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100), 
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0, height: headerHeight,
            child: Container(
              decoration: const BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25))),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0), 
                        child: GestureDetector(onTap: () => _scaffoldKey.currentState?.openDrawer(), child: const Icon(Icons.menu, color: Colors.white, size: 28)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            Text('Welcome Back,', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(_displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(top: headerHeight - 25, left: 20, right: 20, child: _buildFloatingSearchBar()),
        ],
      ),
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  Widget _buildFloatingSearchBar() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const LocationSelectionPage()));
        if (result != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected: ${result['pickup']} → ${result['dropoff']}')));
      },
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))]),
        child: Row(
          children: [
            const SizedBox(width: 15),
            const Icon(Icons.search, color: kPrimaryColor),
            const SizedBox(width: 10),
            const Text('Where To?', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (!_hasLocationPermission)
              GestureDetector(
                onTap: _checkAndRequestLocation, // ✅ UPDATED to use smart flow
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Enable GPS', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBottomNav() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModernNavItem(0, Icons.grid_view_rounded, 'Home'),
              _buildModernNavItem(1, Icons.history_rounded, 'History'),
              _buildModernNavItem(2, Icons.person_outline_rounded, 'Profile'), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.black : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 24),
            if (isSelected) ...[const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12))],
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: currentUser != null ? _firestore.collection('clients').doc(currentUser.uid).snapshots() : null,
        builder: (context, snapshot) {
          String dName = _displayName;
          String dEmail = _clientEmail;
          Widget dImage = _buildProfileImage(size: 60);

          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            if (data['fullName'] != null) dName = data['fullName'];
            if (data['email'] != null) dEmail = data['email'];
            if (data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty) {
              dImage = CachedNetworkImage(imageUrl: data['photoUrl'], width: 60, height: 60, fit: BoxFit.cover, placeholder: (c, u) => const CircularProgressIndicator(), errorWidget: (c, u, e) => Image.asset('assets/client_imag_high.jpg'));
            }
          }

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Colors.black),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ClipOval(child: Container(color: Colors.white, width: 60, height: 60, child: dImage)),
                    const SizedBox(height: 10),
                    Text(dName, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    Text(dEmail, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  ],
                ),
              ),
              
              ListTile(
                leading: const Icon(Icons.help_center_rounded),
                title: const Text('Help Center'),
                onTap: () { 
                  _scaffoldKey.currentState?.closeDrawer(); 
                  _launchUrl('https://unloadweb.com/help-center.html', 'Help Center'); 
                },
              ),
              ListTile(
                leading: const Icon(Icons.question_answer),
                title: const Text('FAQs'),
                onTap: () { 
                  _scaffoldKey.currentState?.closeDrawer(); 
                  _launchUrl('https://unloadweb.com/index.html#faq', 'FAQs'); 
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Terms & Conditions'),
                onTap: () { 
                  _scaffoldKey.currentState?.closeDrawer(); 
                  _launchUrl('https://unloadweb.com/tc.html', 'Terms & Conditions'); 
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Privacy Policy'),
                onTap: () { 
                  _scaffoldKey.currentState?.closeDrawer(); 
                  _launchUrl('https://unloadweb.com/privacy.html', 'Privacy Policy'); 
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red), 
                title: const Text('Log Out', style: TextStyle(color: Colors.red)), 
                onTap: () { 
                  _scaffoldKey.currentState?.closeDrawer(); 
                  _showLogoutDialog(); 
                }
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    final Uri whatsappUrl = Uri.parse("https://wa.me/919938309966");
    try {
      if (!await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch WhatsApp')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening WhatsApp')),
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Closes dialog
                await FirebaseAuth.instance.signOut();
                if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const OnboardingPage()), (route) => false);
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class ModernServiceCard extends StatelessWidget {
  final String image;
  final String title;
  
  const ModernServiceCard({super.key, required this.image, required this.title});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120, 
      margin: const EdgeInsets.only(right: 15, bottom: 5, top: 5),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1), // Thin crisp border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)), // Matches container border minus 1
              child: Image.asset(image, width: double.infinity, fit: BoxFit.cover)
            )
          ),
          Padding(
            padding: const EdgeInsets.all(12), 
            child: Text(
              title, 
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.2), // Tighter, slightly smaller font
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          ),
        ]
      ),
    );
  }
}

class PromoImage extends StatelessWidget {
  final String image;
  const PromoImage({super.key, required this.image});
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 5), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset(image, fit: BoxFit.cover, width: double.infinity)));
  }
}

class BenefitCard extends StatelessWidget {
  final String image;
  final String title;
  const BenefitCard({super.key, required this.image, required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 5), child: Column(children: [
        ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset(image, height: 160, width: double.infinity, fit: BoxFit.cover)),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ]));
  }
}