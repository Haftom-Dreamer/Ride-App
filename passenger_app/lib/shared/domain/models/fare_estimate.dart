class FareEstimate {
  final double distanceKm;
  final double estimatedFare;
  final String vehicleType;

  const FareEstimate({
    required this.distanceKm,
    required this.estimatedFare,
    required this.vehicleType,
  });

  factory FareEstimate.fromJson(Map<String, dynamic> json) {
    return FareEstimate(
      distanceKm: (json['distance_km'] as num).toDouble(),
      estimatedFare: (json['estimated_fare'] as num).toDouble(),
      vehicleType: json['vehicle_type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distance_km': distanceKm,
      'estimated_fare': estimatedFare,
      'vehicle_type': vehicleType,
    };
  }

  @override
  String toString() {
    return 'FareEstimate(distance: ${distanceKm.toStringAsFixed(2)} km, fare: ETB ${estimatedFare.toStringAsFixed(0)}, vehicle: $vehicleType)';
  }
}


