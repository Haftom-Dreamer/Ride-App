/// Vehicle pricing and configuration constants
class VehicleConstants {
  // Vehicle Types
  static const String economy = 'economy';
  static const String standard = 'standard';
  static const String premium = 'premium';

  // Vehicle Pricing (ETB - Ethiopian Birr)
  static const Map<String, Map<String, int>> vehiclePricing = {
    economy: {
      'minPrice': 30,
      'maxPrice': 50,
      'capacity': 3,
    },
    standard: {
      'minPrice': 50,
      'maxPrice': 80,
      'capacity': 4,
    },
    premium: {
      'minPrice': 80,
      'maxPrice': 120,
      'capacity': 6,
    },
  };

  // Vehicle Display Names
  static const Map<String, String> vehicleNames = {
    economy: 'Economy (Bajaj)',
    standard: 'Standard Car',
    premium: 'Premium (SUV)',
  };

  // Vehicle Icons
  static const Map<String, String> vehicleIcons = {
    economy: '🛺',
    standard: '🚗',
    premium: '🚙',
  };

  // Estimated Arrival Times
  static const Map<String, String> vehicleEta = {
    economy: '2 min',
    standard: '5 min',
    premium: '8 min',
  };

  /// Get vehicle pricing info
  static Map<String, int> getVehiclePricing(String vehicleType) {
    return vehiclePricing[vehicleType] ?? vehiclePricing[economy]!;
  }

  /// Get vehicle display name
  static String getVehicleName(String vehicleType) {
    return vehicleNames[vehicleType] ?? vehicleNames[economy]!;
  }

  /// Get vehicle icon
  static String getVehicleIcon(String vehicleType) {
    return vehicleIcons[vehicleType] ?? vehicleIcons[economy]!;
  }

  /// Get vehicle ETA
  static String getVehicleEta(String vehicleType) {
    return vehicleEta[vehicleType] ?? vehicleEta[economy]!;
  }

  /// Calculate average fare for a vehicle type
  static double getAverageFare(String vehicleType) {
    final pricing = getVehiclePricing(vehicleType);
    return (pricing['minPrice']! + pricing['maxPrice']!) / 2.0;
  }
}
