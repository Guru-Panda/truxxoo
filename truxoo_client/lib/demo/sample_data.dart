import 'package:random_string/random_string.dart';
import '../model/trip_data.dart';

String generateTripPin() {
  return randomNumeric(4);
}

Trip createSampleTrip({
  required String pickupLocation,
  required String dropoffLocation,
}) {
  return Trip(
    tripId: 'TRIP_${DateTime.now().millisecondsSinceEpoch}',
    driverId: 'DRIVER_001',
    driverName: 'Soumesh',
    driverPhone: '+919876543210',
    driverLocation: 'Odisha',
    vehicleNumber: 'HJ94BS93B',
    vehicleModel: 'Tata signa 3532 open',
    driverRating: 4.8,
    driverImage: '', // Add network image URL if available
    vehicleImage: '', // Add network image URL if available
    pickupLocation: pickupLocation,
    dropoffLocation: dropoffLocation,
    etaMinutes: 4,
    tripPin: generateTripPin(),
    createdAt: DateTime.now(),
  );
}