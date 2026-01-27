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
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/services.dart';
import 'client_side_my_accounts.dart';

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
    this.displayName = 'Guru Prasad Panda',
    this.displayProfilePicture = 'assets/client_image.webp',
    this.isUsingLocalImage = false,
    this.clientPhone = "8875658758",
    this.clientEmail = "guru34@gmail.com",
    this.companyName = "ABC Logistics",
    this.companyRegNumber = "REG123456789",
  });

  @override
  State<ClientSideHome> createState() => _ClientSideHomeState();
}

class _ClientSideHomeState extends State<ClientSideHome> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  DateTime? _lastBackPressTime;
  
  // Profile data that can be updated
  late bool _isUsingLocalImage;
  late String _displayProfilePicture;
  late String _displayName;
  late String _clientPhone;
  late String _clientEmail;
  late String _companyName;
  late String _companyRegNumber;
  
  final PageController _pageController = PageController(viewportFraction: 0.97);
  Timer? _timer;
  int _currentPage = 0;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize profile data from widget
    _displayName = widget.displayName;
    _displayProfilePicture = widget.displayProfilePicture;
    _isUsingLocalImage = widget.isUsingLocalImage;
    _clientPhone = widget.clientPhone;
    _clientEmail = widget.clientEmail;
    _companyName = widget.companyName;
    _companyRegNumber = widget.companyRegNumber;
    
    _startTimer();
    BackButtonInterceptor.add(_backButtonInterceptor);
    
    // Request location permission when app starts
    _requestLocationPermission();
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermanentlyDeniedDialog();
        return;
      }

      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        if (mounted) {
          setState(() {
            _hasLocationPermission = true;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location access granted! You can now use map features.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error requesting location permission: $e');
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_off, color: Colors.orange),
              SizedBox(width: 8),
              Text('Location Services'),
            ],
          ),
          content: const Text(
            'Location services are disabled. Please enable location services in your device settings to use location-based features.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openLocationSettings();
              },
              child: const Text('Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_disabled, color: Colors.red),
              SizedBox(width: 8),
              Text('Location Permission'),
            ],
          ),
          content: const Text(
            'Location permission is permanently denied. To use location features, please enable location permission in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('App Settings'),
            ),
          ],
        );
      },
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (!mounted) return;
      
      if (_currentPage < 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // Already on home
        break;
      case 1:
        _navigateToHistory();
        break;
      case 2:
        _navigateToMap();
        break;
      case 3:
        _navigateToMyAccount();
        break;
    }
  }

  void _navigateToMap() {
    if (!_hasLocationPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location permission required for map features'),
          action: SnackBarAction(
            label: 'Grant',
            onPressed: _requestLocationPermission,
          ),
        ),
      );
      // Reset to home tab
      setState(() {
        _selectedIndex = 0;
      });
      return;
    }
    // TODO: Navigate to map page
    print('Navigate to map');
    // Reset to home tab for now since map page doesn't exist
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _navigateToMyAccount() {
    // Close drawer if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyAccountClient(
          currentProfileImagePath: _displayProfilePicture,
          isLocalImage: _isUsingLocalImage,
          clientName: _displayName,
          clientPhone: _clientPhone,
          clientEmail: _clientEmail,
          companyName: _companyName,
          companyRegNumber: _companyRegNumber,
        ),
      ),
    ).then((_) {
      // Reset selected index when returning
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    });
  }

  void _navigateToHistory() {
    // Close drawer if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientHistory(
          displayName: _displayName,
          displayProfilePicture: _displayProfilePicture,
          isUsingLocalImage: _isUsingLocalImage,
        ),
      ),
    ).then((_) {
      // Reset selected index when returning
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    });
  }

  void _navigateToTrackTruck() {
    // Close drawer if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackTruck(
          displayName: _displayName,
          displayProfilePicture: _displayProfilePicture,
          isUsingLocalImage: _isUsingLocalImage,
        ),
      ),
    );
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    // If drawer is open, close it
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
      return true;
    }
    
    // If not on home tab, switch to home tab
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return true;
    }
    
    // Double press to exit
    final now = DateTime.now();
    if (_lastBackPressTime == null || 
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return true;
    }
    
    // Exit app
    SystemNavigator.pop();
    return true;
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    
    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.black : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url, String title) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $title')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching $title')),
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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context); // Close drawer
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const OnboardingPage()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenHeight * 0.07),
        child: AppBar(
          backgroundColor: Colors.black,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          centerTitle: false,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  'Truxoo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      
      drawer: _buildDrawer(),
      
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Where To?" search field
              _buildSearchField(),

              const SizedBox(height: 80),

              // Services Section
              const Text(
                'Services',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),
              
              // Service Cards
              SizedBox(
                height: 141,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    ServiceCard(
                      image: 'assets/driver_image.webp',
                      title: 'Logistics',
                    ),
                    ServiceCard(
                      image: 'assets/driver_image.webp',
                      title: 'Pre-booking', 
                    ),
                    ServiceCard(
                      image: 'assets/driver_image.webp',
                      title: 'MCVs', 
                    ),
                    ServiceCard(
                      image: 'assets/driver_image.webp',
                      title: 'Container', 
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 5),
              
              // Track the Truck Button
              SizedBox(
                width: 160,
                child: ElevatedButton(
                  onPressed: _navigateToTrackTruck,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6BF15E),
                    foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 1,
                  ),
                  child: const Text(
                    'Track the Truck',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Image Carousel
              SizedBox(
                height: 170,
                child: PageView(
                  controller: _pageController, 
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/driver_image.webp',
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/driver_image.webp',
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Benefits Section
              const Text(
                'Benefits',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                height: 230,
                child: PageView(
                  controller: PageController(viewportFraction: 0.97),
                  children: const [
                    BenefitCard(
                      image: 'assets/driver_image.webp',
                      title: 'Connecting India',
                    ),
                    BenefitCard(
                      image: 'assets/driver_image.webp',
                      title: 'Logistics Digitalized',
                    ),
                    BenefitCard(
                      image: 'assets/driver_image.webp',
                      title: 'Live Tracking',
                    ),
                  ],
                ),
              ), 
            ],
          ),
        ),
      ),
      
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -1),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade300,
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.home, 'Home'),
            _buildNavItem(1, Icons.history, 'History'),
            _buildNavItem(2, Icons.location_on, 'Map'),
            _buildNavItem(3, Icons.person, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LocationSelectionPage(),
          ),
        );
        
        if (result != null && mounted) {
          print('Pickup: ${result['pickup']}');
          print('Dropoff: ${result['dropoff']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected: ${result['pickup']} → ${result['dropoff']}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 12),
              const Text(
                'Where To?',
                style: TextStyle(
                  color: Color.fromARGB(255, 25, 25, 25),
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!_hasLocationPermission)
                GestureDetector(
                  onTap: _requestLocationPermission,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Enable Location',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.black,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  backgroundImage: _isUsingLocalImage 
                    ? FileImage(File(_displayProfilePicture))
                    : AssetImage(_displayProfilePicture) as ImageProvider,
                ),
                const SizedBox(height: 10),
                Text(
                  _displayName,  
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _clientEmail,  
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('My Account'),
            onTap: _navigateToMyAccount, 
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('History & Payments'),
            onTap: _navigateToHistory,
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Track the Truck'),
            onTap: _navigateToTrackTruck,
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              _hasLocationPermission ? Icons.location_on : Icons.location_off,
              color: _hasLocationPermission ? Colors.green : Colors.orange,
            ),
            title: Text(_hasLocationPermission ? 'Location Enabled' : 'Enable Location'),
            subtitle: Text(_hasLocationPermission 
              ? 'Location access granted' 
              : 'Tap to enable location access'),
            onTap: _hasLocationPermission ? null : _requestLocationPermission,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.question_answer),
            title: const Text('FAQs'),
            onTap: () async {
              Navigator.pop(context);
              await _launchUrl('https://www.truxxo.com/faqs', 'FAQs');
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms & Conditions'),
            onTap: () async {
              Navigator.pop(context);
              await _launchUrl('https://www.truxoo.com/terms', 'Terms & Conditions');
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Helpline'),
            onTap: () async {
              Navigator.pop(context);
              await _launchUrl('https://www.truxoo.com/helpline', 'Helpline');
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About Us'),
            onTap: () async {
              Navigator.pop(context);
              await _launchUrl('https://www.truxoo.com/about-us', 'About Us');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red)),
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  final String image;
  final String title;
  
  const ServiceCard({
    super.key,
    required this.image,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 32) / 3;

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.0),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.asset(
              image,
              height: 90,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BenefitCard extends StatelessWidget {
  final String image;
  final String title;

  const BenefitCard({
    super.key,
    required this.image,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              image,
              height: 170,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}