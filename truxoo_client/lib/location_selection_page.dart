import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // ✅ Added
import 'user_selection_page.dart';

class LocationSelectionPage extends StatefulWidget {
  const LocationSelectionPage({super.key});

  @override
  State<LocationSelectionPage> createState() => _LocationSelectionPageState();
}

class _LocationSelectionPageState extends State<LocationSelectionPage> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final String googleApiKey = "AIzaSyDTCzneUhpD2e-HinMiRhUGKlfX_D7fn9c";

  // ✅ Map State Variables
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  // Default center (India)
  static const LatLng _initialPosition = LatLng(20.5937, 78.9629); 

  double? _pickupLat;
  double? _pickupLng;
  double? _dropoffLat;
  double? _dropoffLng;

  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_backButtonInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _pickupController.dispose();
    _dropoffController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    Navigator.pop(context);
    return true;
  }

  void _navigateToHome() {
    Navigator.pop(context);
  }

  void _navigateToUserSelection() {
    if (_pickupLat == null || _pickupLng == null || _dropoffLat == null || _dropoffLng == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select valid locations from the list')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserSelectionPage(
          pickupLocation: _pickupController.text,
          dropoffLocation: _dropoffController.text,
          pickupLat: _pickupLat!,
          pickupLng: _pickupLng!,
          dropoffLat: _dropoffLat!,
          dropoffLng: _dropoffLng!,
        ),
      ),
    );
  }

  // ✅ FUNCTION: Update Map Markers & Camera
  void _updateMap() {
    Set<Marker> newMarkers = {};
    Set<Polyline> newPolylines = {};
    LatLng? pickupPos;
    LatLng? dropPos;

    // 1. Setup Pickup Marker
    if (_pickupLat != null && _pickupLng != null) {
      pickupPos = LatLng(_pickupLat!, _pickupLng!);
      newMarkers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: pickupPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: "Pickup Location"),
      ));
    }

    // 2. Setup Dropoff Marker
    if (_dropoffLat != null && _dropoffLng != null) {
      dropPos = LatLng(_dropoffLat!, _dropoffLng!);
      newMarkers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: dropPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "Drop Off Location"),
      ));
    }

    // 3. Draw Line (Polyline)
    if (pickupPos != null && dropPos != null) {
      newPolylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [pickupPos, dropPos],
        color: Colors.blue,
        width: 4,
        geodesic: true,
      ));
    }

    setState(() {
      _markers = newMarkers;
      _polylines = newPolylines;
    });

    // 4. Animate Camera to fit points
    if (_mapController != null) {
      if (pickupPos != null && dropPos != null) {
        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(
            pickupPos.latitude < dropPos.latitude ? pickupPos.latitude : dropPos.latitude,
            pickupPos.longitude < dropPos.longitude ? pickupPos.longitude : dropPos.longitude,
          ),
          northeast: LatLng(
            pickupPos.latitude > dropPos.latitude ? pickupPos.latitude : dropPos.latitude,
            pickupPos.longitude > dropPos.longitude ? pickupPos.longitude : dropPos.longitude,
          ),
        );
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      } else if (pickupPos != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pickupPos, 15));
      } else if (dropPos != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(dropPos, 15));
      }
    }
  }

  // ✅ FUNCTION: Open Full Screen Map
  void _openFullScreenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMapPage(
          markers: _markers,
          polylines: _polylines,
          initialPosition: (_pickupLat != null && _pickupLng != null) 
              ? LatLng(_pickupLat!, _pickupLng!) 
              : _initialPosition,
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Location permissions are denied';
      }
      if (permission == LocationPermission.deniedForever) throw 'Location permissions are permanently denied.';

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      _pickupLat = position.latitude;
      _pickupLng = position.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = [place.name, place.subLocality, place.locality, place.postalCode]
            .where((e) => e != null && e.isNotEmpty).join(', ');
        setState(() => _pickupController.text = address);
      }
      
      // Update the Map
      _updateMap();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  void _onPickupSelected(Prediction prediction) {
    setState(() {
      _pickupController.text = prediction.description ?? '';
      if (prediction.lat != null) _pickupLat = double.tryParse(prediction.lat!);
      if (prediction.lng != null) _pickupLng = double.tryParse(prediction.lng!);
      // Update Map
      _updateMap();
    });
  }

  void _onDropoffSelected(Prediction prediction) {
    setState(() {
      _dropoffController.text = prediction.description ?? '';
      if (prediction.lat != null) _dropoffLat = double.tryParse(prediction.lat!);
      if (prediction.lng != null) _dropoffLng = double.tryParse(prediction.lng!);
      // Update Map
      _updateMap();
    });
  }

  Widget _buildDropdownItem(BuildContext context, int index, Prediction prediction) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3)]),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, color: Colors.grey.shade600, size: 16),
            const SizedBox(width: 12),
            Expanded(child: Text(prediction.structuredFormatting?.mainText ?? prediction.description ?? "", maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
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
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: _navigateToHome),
        title: const Text("Select Location", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // ✅ HEADER MAP (Clickable to Expand)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.30, // 30% Height
            width: double.infinity,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: const CameraPosition(target: _initialPosition, zoom: 5),
                  markers: _markers,
                  polylines: _polylines,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  rotateGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                ),
                // Transparent layer to catch clicks
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _openFullScreenMap,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Expand Icon
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.fullscreen, color: Colors.black),
                      onPressed: _openFullScreenMap,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ✅ SCROLLABLE INPUTS
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  
                  // PICKUP
                  Container(
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                    child: GooglePlaceAutoCompleteTextField(
                      textEditingController: _pickupController,
                      googleAPIKey: googleApiKey,
                      inputDecoration: InputDecoration(
                        prefixIcon: const Icon(Icons.my_location, color: Colors.green),
                        hintText: 'Enter pick up',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      debounceTime: 600,
                      countries: const ["in"],
                      isLatLngRequired: true,
                      getPlaceDetailWithLatLng: _onPickupSelected,
                      itemClick: _onPickupSelected,
                      itemBuilder: _buildDropdownItem,
                    ),
                  ),
                  
                  // Current Location Button
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _isFetchingLocation ? null : _getCurrentLocation,
                    child: Row(
                      children: [
                        if (_isFetchingLocation) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) else const Icon(Icons.gps_fixed, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(_isFetchingLocation ? "Fetching..." : "Use current location", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  // DROPOFF
                  Container(
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                    child: GooglePlaceAutoCompleteTextField(
                      textEditingController: _dropoffController,
                      googleAPIKey: googleApiKey,
                      inputDecoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                        hintText: 'Enter drop off',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      debounceTime: 600,
                      countries: const ["in"],
                      isLatLngRequired: true,
                      getPlaceDetailWithLatLng: _onDropoffSelected,
                      itemClick: _onDropoffSelected,
                      itemBuilder: _buildDropdownItem,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        
          // SUBMIT BUTTON
          Container(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_pickupController.text.isNotEmpty && _dropoffController.text.isNotEmpty) {
                    _navigateToUserSelection();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter both pickup and drop-off locations')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Submit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ NEW PAGE: Full Screen Interactive Map
class FullScreenMapPage extends StatelessWidget {
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final LatLng initialPosition;

  const FullScreenMapPage({
    super.key,
    required this.markers,
    required this.polylines,
    required this.initialPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialPosition, zoom: 12),
            markers: markers,
            polylines: polylines,
            zoomControlsEnabled: true,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) {
              // Auto-fit if markers exist
              if (markers.length > 1) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  List<double> lats = markers.map((m) => m.position.latitude).toList();
                  List<double> lngs = markers.map((m) => m.position.longitude).toList();
                  lats.sort(); lngs.sort();
                  controller.animateCamera(CameraUpdate.newLatLngBounds(
                    LatLngBounds(
                      southwest: LatLng(lats.first, lngs.first),
                      northeast: LatLng(lats.last, lngs.last),
                    ),
                    50 // padding
                  ));
                });
              }
            },
          ),
          Positioned(
            top: 40,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}