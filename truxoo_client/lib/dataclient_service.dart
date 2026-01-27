import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';

// ========== DATA CLASSES ==========

class ClientRegistrationData {
  final String name;
  final String phoneNumber;
  final String email;
  final String companyName;
  final String companyRegNumber;
  final File profilePhoto;

  ClientRegistrationData({
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.companyName,
    required this.companyRegNumber,
    required this.profilePhoto,
  });
}

class RegistrationResult {
  final bool success;
  final String? message;
  final String? downloadUrl;
  final String? clientId;

  RegistrationResult({
    required this.success,
    this.message,
    this.downloadUrl,
    this.clientId,
  });
}

class PhoneCheckResult {
  final bool exists;
  final String? userType; 
  final String? message;
  final Map<String, dynamic>? userData;
  final String? documentId;

  PhoneCheckResult({
    required this.exists,
    this.userType,
    this.message,
    this.userData,
    this.documentId,
  });

  String get displayName => userData?['full_name'] ?? userData?['name'] ?? 'User';
  String get profilePhotoUrl => userData?['profile_photo_url'] ?? '';
  String get email => userData?['email'] ?? '';
  String get companyName => userData?['company_name'] ?? '';
  String get companyRegNumber => userData?['company_reg_number'] ?? '';
  String get phoneNumber => userData?['phone_number'] ?? userData?['phoneNumber'] ?? '';
}

class TrackingResult {
  final bool success;
  final String? message;
  final DeliveryInfo? deliveryInfo;

  TrackingResult({
    required this.success,
    this.message,
    this.deliveryInfo,
  });
}

class DeliveryInfo {
  final String trackingId;
  final String documentId;
  final String truckId;
  final String driverName;
  final String driverPhone;
  final String driverId;
  final String pickupLocation;
  final String dropLocation;
  final String status;
  final String estimatedDelivery;
  final String currentLocation;
  final double latitude;
  final double longitude;
  final DateTime lastUpdated;
  final DateTime createdAt;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final double? fare;
  final String? paymentStatus;

  DeliveryInfo({
    required this.trackingId,
    required this.documentId,
    required this.truckId,
    required this.driverName,
    required this.driverPhone,
    required this.driverId,
    required this.pickupLocation,
    required this.dropLocation,
    required this.status,
    required this.estimatedDelivery,
    required this.currentLocation,
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
    required this.createdAt,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    this.fare,
    this.paymentStatus,
  });

  factory DeliveryInfo.fromFirestore(Map<String, dynamic> data, String docId) {
    DateTime lastUpdated = DateTime.now();
    DateTime createdAt = DateTime.now();

    if (data['updated_at'] != null) {
      lastUpdated = (data['updated_at'] as Timestamp).toDate();
    }
    if (data['created_at'] != null) {
      createdAt = (data['created_at'] as Timestamp).toDate();
    }

    double lat = 0.0;
    double lng = 0.0;

    // Handle different coordinate structures
    if (data['current_location'] != null && data['current_location'] is Map) {
      final locData = data['current_location'] as Map;
      lat = (locData['latitude'] ?? 0.0).toDouble();
      lng = (locData['longitude'] ?? 0.0).toDouble();
    } else if (data['driver_location'] != null && data['driver_location'] is Map) {
      final locData = data['driver_location'] as Map;
      lat = (locData['latitude'] ?? 0.0).toDouble();
      lng = (locData['longitude'] ?? 0.0).toDouble();
    }

    double? fare;
    if (data['fare'] != null) {
      fare = (data['fare'] is int)
          ? (data['fare'] as int).toDouble()
          : data['fare'] as double?;
    }

    return DeliveryInfo(
      trackingId: data['tracking_id'] ?? data['booking_id'] ?? docId,
      documentId: docId,
      truckId: data['truck_id'] ?? data['vehicle_number'] ?? '',
      driverName: data['driver_name'] ?? '',
      driverPhone: data['driver_phone'] ?? '',
      driverId: data['driver_id'] ?? data['driverId'] ?? '',
      pickupLocation: data['pickup_location'] ?? data['pickup_address'] ?? 'N/A',
      dropLocation: data['drop_location'] ?? data['drop_address'] ?? 'N/A',
      status: data['status'] ?? 'Unknown',
      estimatedDelivery: data['estimated_delivery'] ?? data['eta'] ?? '',
      currentLocation: data['current_location_address'] ??
          data['current_address'] ??
          (lat != 0 ? 'Lat: $lat, Lng: $lng' : 'Location not available'),
      latitude: lat,
      longitude: lng,
      lastUpdated: lastUpdated,
      createdAt: createdAt,
      clientId: data['client_id'] ?? data['clientId'] ?? '',
      clientName: data['client_name'] ?? '',
      clientPhone: data['client_phone'] ?? '',
      fare: fare,
      paymentStatus: data['payment_status'],
    );
  }
}

// ========== MAIN SERVICE CLASS ==========
class ClientDataService {
  static const String _dbName = 'truxoodriver';
  
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static FirebaseFirestore get _db {
    try {
      return FirebaseFirestore.instanceFor(
        app: Firebase.app(), 
        databaseId: _dbName,
      );
    } catch (e) {
      print("⚠️ Using default DB (fallback): $e");
      return FirebaseFirestore.instance;
    }
  }

  // ==================== PHONE CHECK ====================
  static Future<PhoneCheckResult> checkPhoneExists(String phoneNumber) async {
    try {
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      final formattedPhone = '+91$cleanPhone';
      final searchNums = [cleanPhone, formattedPhone];
      final fieldNames = ['phoneNumber', 'phone_number', 'phone', 'mobile'];

      print("🔍 Service: Searching DB '$_dbName' for: $searchNums");

      // 1. Check Drivers
      for (String field in fieldNames) {
        final driverQuery = await _db.collection('drivers').where(field, whereIn: searchNums).limit(1).get();
        if (driverQuery.docs.isNotEmpty) {
          final data = driverQuery.docs.first.data();
          return PhoneCheckResult(
            exists: true,
            userType: 'driver',
            message: 'Number already registered as a driver.',
            userData: data,
            documentId: driverQuery.docs.first.id,
          );
        }
      }

      // 2. Check Clients
      for (String field in fieldNames) {
        final clientQuery = await _db.collection('clients').where(field, whereIn: searchNums).limit(1).get();
        if (clientQuery.docs.isNotEmpty) {
          final data = clientQuery.docs.first.data();
          return PhoneCheckResult(
            exists: true,
            userType: 'client',
            message: 'Already registered.',
            userData: data,
            documentId: clientQuery.docs.first.id,
          );
        }
      }

      return PhoneCheckResult(exists: false);
    } catch (e) {
      print("❌ Service Error: $e");
      return PhoneCheckResult(exists: false);
    }
  }

  // ==================== REGISTRATION ====================
  static Future<RegistrationResult> registerClient({required ClientRegistrationData data}) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return RegistrationResult(success: false, message: 'Authentication required.');
      }

      String uid = currentUser.uid;

      final phoneCheck = await checkPhoneExists(data.phoneNumber);
      if (phoneCheck.exists && phoneCheck.documentId != uid) {
        return RegistrationResult(success: false, message: phoneCheck.message ?? 'Number registered to another account.');
      }

      String? downloadUrl;
      try {
        final storageRef = _storage.ref().child('client_photos/$uid.jpg');
        await storageRef.putFile(data.profilePhoto, SettableMetadata(contentType: 'image/jpeg'));
        downloadUrl = await storageRef.getDownloadURL();
      } catch (e) {
        print("⚠️ Photo upload failed: $e");
      }

      final cleanPhone = data.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      final standardPhone = '+91${cleanPhone.length == 10 ? cleanPhone : cleanPhone.substring(cleanPhone.length - 10)}';
      
      await _db.collection('clients').doc(uid).set({
        'uid': uid,
        'full_name': data.name,
        'phone_number': standardPhone,
        'email': data.email,
        'company_name': data.companyName,
        'company_reg_number': data.companyRegNumber,
        'profile_photo_url': downloadUrl ?? '',
        'account_created': FieldValue.serverTimestamp(),
        'role': 'client',
        'is_verified': true,
        'is_active': true,
      }, SetOptions(merge: true));

      return RegistrationResult(success: true, message: 'Registration successful', downloadUrl: downloadUrl, clientId: uid);
    } catch (e) {
      return RegistrationResult(success: false, message: 'Registration failed: $e');
    }
  }

  // ==================== BOOKING (NEW) ====================
  
  static Future<bool> createBookingRequest(Map<String, dynamic> bookingData) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) throw "User not logged in";

      bookingData['client_id'] = user.uid;
      bookingData['created_at'] = FieldValue.serverTimestamp();
      bookingData['status'] = 'pending';

      await _db.collection('booking_requests').add(bookingData);
      
      return true;
    } catch (e) {
      print("❌ Booking Creation Error: $e");
      return false;
    }
  }

  // ==================== GETTERS ====================

  static Future<Map<String, dynamic>?> getClientByPhone(String phoneNumber) async {
    final result = await checkPhoneExists(phoneNumber);
    return result.userData;
  }

  static Future<Map<String, dynamic>?> getClientByUid(String uid) async {
    try {
      final doc = await _db.collection('clients').doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      return null;
    }
  }

  // ==================== TRACKING ====================

  static Future<TrackingResult> searchTracking(String trackingId) async {
    try {
      if (trackingId.trim().isEmpty) return TrackingResult(success: false, message: 'Enter tracking number');
      final searchId = trackingId.trim();
      DocumentSnapshot? foundDoc;

      try {
        final doc = await _db.collection('booking_requests').doc(searchId).get();
        if (doc.exists) foundDoc = doc;
      } catch (_) {}

      if (foundDoc == null) {
        final query = await _db.collection('booking_requests').where('tracking_id', isEqualTo: searchId).limit(1).get();
        if (query.docs.isNotEmpty) foundDoc = query.docs.first;
      }

      if (foundDoc != null && foundDoc.exists) {
        return TrackingResult(
          success: true,
          message: 'Found',
          deliveryInfo: DeliveryInfo.fromFirestore(foundDoc.data() as Map<String, dynamic>, foundDoc.id),
        );
      }
      return TrackingResult(success: false, message: 'Not found');
    } catch (e) {
      return TrackingResult(success: false, message: 'Error: $e');
    }
  }

  static Stream<DeliveryInfo?> getBookingStream(String documentId) {
    return _db.collection('booking_requests').doc(documentId).snapshots().map((s) {
      return s.exists ? DeliveryInfo.fromFirestore(s.data()!, s.id) : null;
    });
  }
  
  // ✅ ADDED THIS MISSING METHOD
  static Future<DeliveryInfo?> refreshBookingData(String documentId) async {
    try {
      final doc = await _db.collection('booking_requests').doc(documentId).get();
      return doc.exists ? DeliveryInfo.fromFirestore(doc.data()!, doc.id) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<DeliveryInfo>> getClientBookings(String clientId) async {
    try {
      final query = await _db.collection('booking_requests')
          .where('client_id', isEqualTo: clientId)
          .orderBy('created_at', descending: true)
          .get();
      return query.docs.map((d) => DeliveryInfo.fromFirestore(d.data(), d.id)).toList();
    } catch (e) {
      print("Error fetching bookings: $e");
      return [];
    }
  }
}