class Trip {
  final String tripId;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String driverLocation;
  final String vehicleNumber;
  final String vehicleModel;
  final double driverRating;
  final String driverImage;
  final String vehicleImage;
  final String pickupLocation;
  final String dropoffLocation;
  final int etaMinutes;
  final String tripPin;
  final DateTime createdAt;

  Trip({
    required this.tripId,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.driverLocation,
    required this.vehicleNumber,
    required this.vehicleModel,
    required this.driverRating,
    required this.driverImage,
    required this.vehicleImage,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.etaMinutes,
    required this.tripPin,
    required this.createdAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      tripId: json['tripId'] ?? '',
      driverId: json['driverId'] ?? '',
      driverName: json['driverName'] ?? 'Soumesh',
      driverPhone: json['driverPhone'] ?? '',
      driverLocation: json['driverLocation'] ?? 'Odisha',
      vehicleNumber: json['vehicleNumber'] ?? 'HJ94BS93B',
      vehicleModel: json['vehicleModel'] ?? 'Tata signa 3532 open',
      driverRating: (json['driverRating'] ?? 4.8).toDouble(),
      driverImage: json['driverImage'] ?? '',
      vehicleImage: json['vehicleImage'] ?? '',
      pickupLocation: json['pickupLocation'] ?? '',
      dropoffLocation: json['dropoffLocation'] ?? '',
      etaMinutes: json['etaMinutes'] ?? 4,
      tripPin: json['tripPin'] ?? '5678',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tripId': tripId,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverLocation': driverLocation,
      'vehicleNumber': vehicleNumber,
      'vehicleModel': vehicleModel,
      'driverRating': driverRating,
      'driverImage': driverImage,
      'vehicleImage': vehicleImage,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'etaMinutes': etaMinutes,
      'tripPin': tripPin,
      'createdAt': createdAt.toString(),
    };
  }
}