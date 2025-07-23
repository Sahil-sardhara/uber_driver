import 'package:cloud_firestore/cloud_firestore.dart';

class TripRequest {
  final String tripId;
  final String userId;
  final String userName;
  final LatLng pickupLocation;
  final String pickupAddress;
  final LatLng destinationLocation;
  final String destinationAddress;
  final String status;
  final Timestamp timestamp;
  final double? fare; // Optional, might be calculated later
  final String? paymentMethod; // Optional

  TripRequest({
    required this.tripId,
    required this.userId,
    required this.userName,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.destinationLocation,
    required this.destinationAddress,
    required this.status,
    required this.timestamp,
    this.fare,
    this.paymentMethod,
  });

  factory TripRequest.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TripRequest(
      tripId: doc.id,
      userId: data['userId'] as String,
      userName: data['userName'] as String,
      pickupLocation: LatLng(
        (data['pickupLocation']['latitude'] as num).toDouble(),
        (data['pickupLocation']['longitude'] as num).toDouble(),
      ),
      pickupAddress: data['pickupAddress'] as String,
      destinationLocation: LatLng(
        (data['destinationLocation']['latitude'] as num).toDouble(),
        (data['destinationLocation']['longitude'] as num).toDouble(),
      ),
      destinationAddress: data['destinationAddress'] as String,
      status: data['status'] as String,
      timestamp: data['timestamp'] as Timestamp,
      fare: (data['fare'] as num?)?.toDouble(),
      paymentMethod: data['paymentMethod'] as String?,
    );
  }

  // Helper for Google Maps LatLng
  static LatLng fromMap(Map<String, dynamic> map) {
    return LatLng(
      (map['latitude'] as num).toDouble(),
      (map['longitude'] as num).toDouble(),
    );
  }
}

// For Google Maps LatLng
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}