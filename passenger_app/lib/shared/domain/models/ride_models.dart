/// Shared ride-related enums and models
enum RideStatus {
  home, // Initial state with bottom sheet
  searchingDestination, // User is searching for destination
  pinDestination, // User is pinning destination on map
  rideConfiguration, // Pickup and destination set, selecting vehicle
  findingDriver, // Searching for available driver
  driverAssigned, // Driver found and assigned
  driverArriving, // Driver on the way to pickup
  onTrip, // Trip in progress
  tripCompleted, // Trip finished, show rating
  canceled, // Ride was canceled
}

enum VehicleType {
  economy, // Bajaj
  standard, // Standard Car
  premium, // SUV
}

/// Vehicle option model
class VehicleOption {
  final VehicleType type;
  final String name;
  final String icon;
  final int minPrice;
  final int maxPrice;
  final int capacity;
  final String eta;

  const VehicleOption({
    required this.type,
    required this.name,
    required this.icon,
    required this.minPrice,
    required this.maxPrice,
    required this.capacity,
    required this.eta,
  });

  /// Create vehicle option from type
  factory VehicleOption.fromType(VehicleType type) {
    switch (type) {
      case VehicleType.economy:
        return const VehicleOption(
          type: VehicleType.economy,
          name: 'Economy (Bajaj)',
          icon: '🛺',
          minPrice: 30,
          maxPrice: 50,
          capacity: 3,
          eta: '2 min',
        );
      case VehicleType.standard:
        return const VehicleOption(
          type: VehicleType.standard,
          name: 'Standard Car',
          icon: '🚗',
          minPrice: 50,
          maxPrice: 80,
          capacity: 4,
          eta: '5 min',
        );
      case VehicleType.premium:
        return const VehicleOption(
          type: VehicleType.premium,
          name: 'Premium (SUV)',
          icon: '🚙',
          minPrice: 80,
          maxPrice: 120,
          capacity: 6,
          eta: '8 min',
        );
    }
  }

  /// Get average fare
  double get averageFare => (minPrice + maxPrice) / 2.0;

  /// Get price range string
  String get priceRange => 'ETB $minPrice-$maxPrice';
}
