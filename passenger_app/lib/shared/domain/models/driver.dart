class Driver {
  final int id;
  final String name;
  final String phoneNumber;
  final String vehicleType;
  final String vehicleDetails;
  final String vehiclePlateNumber;
  final String? profilePicture;
  final double currentLat;
  final double currentLon;
  final String status;
  final double rating;
  final int totalRides;
  final DateTime? lastActive;

  const Driver({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.vehicleType,
    required this.vehicleDetails,
    required this.vehiclePlateNumber,
    this.profilePicture,
    required this.currentLat,
    required this.currentLon,
    required this.status,
    required this.rating,
    required this.totalRides,
    this.lastActive,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as int,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String,
      vehicleType: json['vehicle_type'] as String,
      vehicleDetails: json['vehicle_details'] as String,
      vehiclePlateNumber: json['vehicle_plate_number'] as String,
      profilePicture: json['profile_picture'] as String?,
      currentLat: (json['current_lat'] as num).toDouble(),
      currentLon: (json['current_lon'] as num).toDouble(),
      status: json['status'] as String,
      rating: (json['rating'] as num).toDouble(),
      totalRides: json['total_rides'] as int,
      lastActive: json['last_active'] != null
          ? DateTime.parse(json['last_active'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'vehicle_type': vehicleType,
      'vehicle_details': vehicleDetails,
      'vehicle_plate_number': vehiclePlateNumber,
      'profile_picture': profilePicture,
      'current_lat': currentLat,
      'current_lon': currentLon,
      'status': status,
      'rating': rating,
      'total_rides': totalRides,
      'last_active': lastActive?.toIso8601String(),
    };
  }

  bool get isAvailable => status == 'Available';
  bool get isOnTrip => status == 'On Trip';
  bool get isOffline => status == 'Offline';

  String get displayName => name;
  String get displayVehicle => '$vehicleType - $vehicleDetails';

  Driver copyWith({
    int? id,
    String? name,
    String? phoneNumber,
    String? vehicleType,
    String? vehicleDetails,
    String? vehiclePlateNumber,
    String? profilePicture,
    double? currentLat,
    double? currentLon,
    String? status,
    double? rating,
    int? totalRides,
    DateTime? lastActive,
  }) {
    return Driver(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleDetails: vehicleDetails ?? this.vehicleDetails,
      vehiclePlateNumber: vehiclePlateNumber ?? this.vehiclePlateNumber,
      profilePicture: profilePicture ?? this.profilePicture,
      currentLat: currentLat ?? this.currentLat,
      currentLon: currentLon ?? this.currentLon,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      totalRides: totalRides ?? this.totalRides,
      lastActive: lastActive ?? this.lastActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Driver && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Driver(id: $id, name: $name, status: $status, vehicle: $vehicleType)';
  }
}
