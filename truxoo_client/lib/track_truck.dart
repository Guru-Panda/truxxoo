import 'package:flutter/material.dart';
import 'dart:async';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'client_side_home.dart';
import 'dataclient_service.dart';

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
  
  DeliveryInfo? _currentDelivery;
  String? _errorMessage;
  StreamSubscription? _bookingSubscription;

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_backButtonInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _trackingController.dispose();
    _bookingSubscription?.cancel();
    super.dispose();
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    _navigateToHome();
    return true;
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ClientSideHome(
          displayName: widget.displayName ?? 'Guest User',
          displayProfilePicture: widget.displayProfilePicture ?? 'assets/client_image.webp',
          isUsingLocalImage: widget.isUsingLocalImage,
        ),
      ),
    );
  }

  Future<void> _startTracking(String trackingId) async {
    if (trackingId.trim().isEmpty) {
      _showSnackBar('Please enter a tracking number', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentDelivery = null;
    });

    // Use the service to search
    final result = await ClientDataService.searchTracking(trackingId);

    if (result.success && result.deliveryInfo != null) {
      setState(() {
        _currentDelivery = result.deliveryInfo;
        _isLoading = false;
      });

      // Start real-time updates
      _startRealTimeUpdates(result.deliveryInfo!.documentId);
      
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
      _showSnackBar(result.message ?? 'Not found', Colors.red);
    }
  }

  void _startRealTimeUpdates(String documentId) {
    _bookingSubscription?.cancel();
    
    _bookingSubscription = ClientDataService.getBookingStream(documentId).listen(
      (deliveryInfo) {
        if (mounted && deliveryInfo != null) {
          setState(() {
            _currentDelivery = deliveryInfo;
          });
        }
      },
      onError: (e) {
        print("Real-time update error: $e");
      },
    );
  }

  Future<void> _refreshLocation() async {
    if (_currentDelivery == null) return;

    setState(() => _isLoading = true);

    final updated = await ClientDataService.refreshBookingData(_currentDelivery!.documentId);

    if (updated != null) {
      setState(() {
        _currentDelivery = updated;
        _isLoading = false;
      });
      _showSnackBar('Location updated', Colors.green);
    } else {
      setState(() => _isLoading = false);
      _showSnackBar('Error refreshing', Colors.red);
    }
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
      appBar: AppBar(
        title: const Text('Track Truck'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateToHome,
        ),
        actions: [
          if (_currentDelivery != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _refreshLocation,
            ),
        ],
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
            if (_currentDelivery != null && !_isLoading)
              _buildDeliveryCard(_currentDelivery!, isLargeScreen),
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
            Text(_errorMessage ?? '', style: TextStyle(color: Colors.red[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(DeliveryInfo delivery, bool isLargeScreen) {
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
                Text('ID: ${delivery.trackingId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Chip(
                  label: Text(delivery.status.toUpperCase()),
                  backgroundColor: _getStatusColor(delivery.status).withOpacity(0.2),
                ),
              ],
            ),
            const Divider(),
            if (delivery.driverName.isNotEmpty)
              _buildRow('Driver', delivery.driverName),
            if (delivery.truckId.isNotEmpty)
              _buildRow('Truck', delivery.truckId),
            _buildRow('From', delivery.pickupLocation),
            _buildRow('To', delivery.dropLocation),
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
                  Text(delivery.currentLocation),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${_formatTime(delivery.lastUpdated)}',
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

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'in transit': return Colors.indigo;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }
}