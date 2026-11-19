import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart'; 

import 'client_side_home.dart';

class TrackTruck extends StatefulWidget {
  final String? displayName;
  final String? displayProfilePicture;
  final bool isUsingLocalImage;

  const TrackTruck({
    super.key,
    this.displayName,
    this.displayProfilePicture,
    this.isUsingLocalImage = false,
  });

  @override
  State<TrackTruck> createState() => _TrackTruckState();
}

class _TrackTruckState extends State<TrackTruck> {
  final TextEditingController _trackingController = TextEditingController();
  bool _isLoading = false;
  bool _isTracking = false;
  
  Map<String, dynamic>? _trackingData;
  String? _errorMessage;
  StreamSubscription<DocumentSnapshot>? _locationSubscription;

  // Variables to cache geocoding to prevent API rate-limit spam
  GeoPoint? _lastGeocodedLocation;
  String _lastGeocodedAddress = 'En Route';

  // Use correct Firestore instance
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'truxoodriver',
  );

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_backButtonInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _trackingController.dispose();
    _locationSubscription?.cancel();
    super.dispose();
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    _navigateToHome();
    return true; // Prevents default back behavior
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ClientSideHome(
          displayName: widget.displayName ?? 'Guest User',
          displayProfilePicture: widget.displayProfilePicture ?? 'assets/cclient_imag_high.jpg',
          isUsingLocalImage: widget.isUsingLocalImage,
        ),
      ),
    );
  }

  Future<void> _startTracking(String trackingIdInput) async {
    FocusScope.of(context).unfocus();

    final searchId = trackingIdInput.trim().toUpperCase();  
    if (searchId.isEmpty) {
      _showSnackBar('Please enter a tracking number', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _isTracking = false;
      _errorMessage = null;
      _trackingData = null;
      _locationSubscription?.cancel();
      
      // Reset geocoding cache for new search
      _lastGeocodedLocation = null;
      _lastGeocodedAddress = 'En Route';
    });

    try {
      DocumentSnapshot? foundDoc;

      // Step 1: 2-Step Search (Doc ID first, then trackingId field)
      try {
        if (!searchId.contains('/')) {
          final doc = await _firestore.collection('booking_requests')
              .doc(searchId)
              .get()
              .timeout(const Duration(seconds: 15));
          if (doc.exists) foundDoc = doc;
        }
      } catch (_) {}

      if (foundDoc == null) {
        final query = await _firestore.collection('booking_requests')
            .where('trackingId', isEqualTo: searchId) // Adjusted to match your client schema
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 15));
        if (query.docs.isNotEmpty) foundDoc = query.docs.first;
      }

      if (foundDoc == null || !foundDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Tracking ID Not Found";
        });
        _showSnackBar('Invalid tracking number. No booking found.', Colors.red);
        return;
      }

      final bookingId = foundDoc.id;
      final bookingData = foundDoc.data() as Map<String, dynamic>;
      
      // Step 2: Start streaming the 'locations' collection
      _startLocationStream(bookingId, bookingData, searchId);

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String msg = e.toString();
        if (e is TimeoutException) msg = "Connection timeout.";
        _showSnackBar('Error searching: $msg', Colors.red);
      }
    }
  }

  void _startLocationStream(String bookingId, Map<String, dynamic> initialData, String searchId) {
    _trackingData = {
      'trackingId': initialData['trackingId'] ?? searchId,
      'status': initialData['status'] ?? 'Unknown',
      'driverName': initialData['driverName'] ?? 'Unknown Driver',
      'truckNumber': initialData['truckNumber'] ?? 'Unknown Truck',
      'pickupLocation': initialData['pickupLocation'] ?? '',
      'dropLocation': initialData['dropLocation'] ?? '',
      'currentLocation': 'Waiting for update...',
      'lastUpdated': null,
    };

    _locationSubscription = _firestore
        .collection('locations')
        .doc(bookingId)
        .snapshots()
        .listen((snapshot) async { 
      
      if (mounted && snapshot.exists) {
        final locData = snapshot.data() as Map<String, dynamic>;       
        
        // Get Basic Data
        String statusMsg = locData['status']?.toString() ?? 'En Route';
        DateTime? lastUpdated;
        if (locData['lastUpdated'] != null) {
          lastUpdated = (locData['lastUpdated'] as Timestamp).toDate();
        }

        String locationText = 'En Route';
        
        if (statusMsg == 'atPickup') {
          locationText = 'At Pickup Location';
        } else if (statusMsg == 'completed') {
          locationText = 'Delivered';
        } else if (locData['currentLocation'] != null) {
          
          final rawLocation = locData['currentLocation'];
          
          if (rawLocation is GeoPoint) {
            GeoPoint currentGeo = rawLocation;
            bool shouldGeocode = false;

            // 1km Distance Check to save API requests
            if (_lastGeocodedLocation == null) {
              shouldGeocode = true;
            } else {
              double distance = Geolocator.distanceBetween(
                _lastGeocodedLocation!.latitude,
                _lastGeocodedLocation!.longitude,
                currentGeo.latitude,
                currentGeo.longitude,
              );
              
              if (distance > 1000) { 
                shouldGeocode = true;
              }
            }

            if (shouldGeocode) {
              try {
                List<Placemark> placemarks = await placemarkFromCoordinates(
                  currentGeo.latitude, 
                  currentGeo.longitude
                );

                if (placemarks.isNotEmpty) {
                  Placemark place = placemarks[0];
                  String street = place.thoroughfare ?? '';
                  String locality = place.subLocality ?? place.locality ?? '';
                  
                  if (street.isNotEmpty && locality.isNotEmpty) {
                    _lastGeocodedAddress = "Near $street, $locality";
                  } else if (locality.isNotEmpty) {
                    _lastGeocodedAddress = "Near $locality";
                  } else {
                    _lastGeocodedAddress = "Near ${place.name}";
                  }
                  
                  _lastGeocodedLocation = currentGeo;
                } else {
                  _lastGeocodedAddress = "En Route (${currentGeo.latitude.toStringAsFixed(3)}, ${currentGeo.longitude.toStringAsFixed(3)})";
                }
              } catch (e) {
                if (_lastGeocodedLocation == null) {
                  _lastGeocodedAddress = "En Route (Updating...)";
                }
              }
            }
            
            locationText = _lastGeocodedAddress;
            
          } else {
            locationText = "En Route (Location updating...)";
          }
        }

        if (mounted) {
          setState(() {
            _trackingData!['status'] = statusMsg;
            _trackingData!['lastUpdated'] = lastUpdated;
            _trackingData!['currentLocation'] = locationText; 
          });
        }
      } else if (mounted && !snapshot.exists && _isTracking) {
        // Handle case where location document is deleted
        _locationSubscription?.cancel();
        setState(() {
          _trackingData = null;
          _errorMessage = "Tracking session has expired or been removed.";
        });
      }
      
      if (mounted) {
        setState(() {
          _isTracking = true;
          _isLoading = false;
        });
      }

    }, onError: (e) {
      debugPrint("Error in location stream: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Track Truck', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _navigateToHome,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
        child: Column(
          children: [
            _buildSearchCard(isLargeScreen),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            if (_errorMessage != null && !_isLoading)
              _buildErrorCard(isLargeScreen),
            if (_isTracking && _trackingData != null && !_isLoading)
              _buildDeliveryCard(_trackingData!, isLargeScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard(bool isLargeScreen) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
        child: Column(
          children: [
            TextField(
              controller: _trackingController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Enter Tracking Number',
                hintText: 'e.g., TRX123456',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: _startTracking,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _startTracking(_trackingController.text),
                icon: const Icon(Icons.local_shipping),
                label: Text(_isLoading ? 'Searching...' : 'Track Shipment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(bool isLargeScreen) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 48),
            const SizedBox(height: 12),
            Text(
              'Tracking ID Not Found',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700]),
            ),
            Text(_errorMessage ?? '', style: TextStyle(color: Colors.red[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> data, bool isLargeScreen) {
    final status = data['status'].toString();

    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ID: ${data['trackingId']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Chip(
                  label: Text(status.toUpperCase()),
                  backgroundColor: _getStatusColor(status).withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (data['driverName'].toString().isNotEmpty)
              _buildRow('Driver', data['driverName']),
            if (data['truckNumber'].toString().isNotEmpty)
              _buildRow('Truck', data['truckNumber']),
            _buildRow('From', data['pickupLocation']),
            _buildRow('To', data['dropLocation']),
            const Divider(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📍 Current Location', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(data['currentLocation'] ?? 'Updating...'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (data['lastUpdated'] != null)
              Text(
                'Last updated: ${_formatTime(data['lastUpdated'] as DateTime)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label:', style: TextStyle(color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return DateFormat('dd MMM, hh:mm a').format(dateTime);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'accepted': 
      case 'assigned':
      case 'inprogress':
      case 'enroute':
        return Colors.blue;
      case 'completed': 
      case 'delivered':
        return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }
}