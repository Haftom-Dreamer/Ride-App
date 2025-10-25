enum RideType {
  economy,
  standard,
  premium,
}

class Ride {
  final int id;
  final int passengerId;
  final int? driverId;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLon;
  final String destAddress;
  final double destLat;
  final double destLon;
  final double distanceKm;
  final double fare;
  final String vehicleType;
  final String paymentMethod;
  final String? note;
  final String status;
  final DateTime requestTime;
  final DateTime? assignedTime;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? rating;
  final String? feedback;

  const Ride({
    required this.id,
    required this.passengerId,
    this.driverId,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLon,
    required this.destAddress,
    required this.destLat,
    required this.destLon,
    required this.distanceKm,
    required this.fare,
    required this.vehicleType,
    required this.paymentMethod,
    this.note,
    required this.status,
    required this.requestTime,
    this.assignedTime,
    this.startTime,
    this.endTime,
    this.rating,
    this.feedback,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] as int,
      passengerId: json['passenger_id'] as int,
      driverId: json['driver_id'] as int?,
      pickupAddress: json['pickup_address'] as String? ?? '',
      pickupLat: (json['pickup_lat'] as num).toDouble(),
      pickupLon: (json['pickup_lon'] as num).toDouble(),
      destAddress: json['dest_address'] as String,
      destLat: (json['dest_lat'] as num).toDouble(),
      destLon: (json['dest_lon'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num).toDouble(),
      fare: (json['fare'] as num).toDouble(),
      vehicleType: json['vehicle_type'] as String,
      paymentMethod: json['payment_method'] as String,
      note: json['note'] as String?,
      status: json['status'] as String,
      requestTime: DateTime.parse(json['request_time'] as String),
      assignedTime: json['assigned_time'] != null
          ? DateTime.parse(json['assigned_time'] as String)
          : null,
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'] as String)
          : null,
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      rating: json['rating'] as int?,
      feedback: json['feedback'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'passenger_id': passengerId,
      'driver_id': driverId,
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lon': pickupLon,
      'dest_address': destAddress,
      'dest_lat': destLat,
      'dest_lon': destLon,
      'distance_km': distanceKm,
      'fare': fare,
      'vehicle_type': vehicleType,
      'payment_method': paymentMethod,
      'note': note,
      'status': status,
      'request_time': requestTime.toIso8601String(),
      'assigned_time': assignedTime?.toIso8601String(),
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'rating': rating,
      'feedback': feedback,
    };
  }

  bool get isRequested => status == 'Requested';
  bool get isAssigned => status == 'Assigned';
  bool get isOnTrip => status == 'On Trip';
  bool get isCompleted => status == 'Completed';
  bool get isCancelled => status == 'Cancelled';

  bool get isActive => isRequested || isAssigned || isOnTrip;

  Ride copyWith({
    int? id,
    int? passengerId,
    int? driverId,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLon,
    String? destAddress,
    double? destLat,
    double? destLon,
    double? distanceKm,
    double? fare,
    String? vehicleType,
    String? paymentMethod,
    String? note,
    String? status,
    DateTime? requestTime,
    DateTime? assignedTime,
    DateTime? startTime,
    DateTime? endTime,
    int? rating,
    String? feedback,
  }) {
    return Ride(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      driverId: driverId ?? this.driverId,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLon: pickupLon ?? this.pickupLon,
      destAddress: destAddress ?? this.destAddress,
      destLat: destLat ?? this.destLat,
      destLon: destLon ?? this.destLon,
      distanceKm: distanceKm ?? this.distanceKm,
      fare: fare ?? this.fare,
      vehicleType: vehicleType ?? this.vehicleType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      status: status ?? this.status,
      requestTime: requestTime ?? this.requestTime,
      assignedTime: assignedTime ?? this.assignedTime,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ride && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Ride(id: $id, status: $status, from: $pickupAddress, to: $destAddress)';
  }
}
