import 'package:latlong2/latlong.dart';

/// Location model for Tigray region
class TigrayLocation {
  final String id;
  final String name;
  final String city;
  final String category;
  final LatLng coordinates;
  final String? description;

  const TigrayLocation({
    required this.id,
    required this.name,
    required this.city,
    required this.category,
    required this.coordinates,
    this.description,
  });
}

/// All locations in Tigray region (Mekelle & Adigrat)
class TigrayLocations {
  // Map Centers
  static const LatLng mekelleCenter = LatLng(13.4967, 39.4753);
  static const LatLng adigratCenter = LatLng(14.2769, 39.4619);

  // Default map center (Mekelle)
  static const LatLng defaultCenter = mekelleCenter;
  static const double defaultZoom = 13.0;

  // Mekelle Locations
  static const List<TigrayLocation> mekelleLocations = [
    // Neighborhoods
    TigrayLocation(
      id: 'mekelle_hawelti',
      name: 'Hawelti',
      city: 'Mekelle',
      category: 'neighborhood',
      coordinates: LatLng(13.4833, 39.4750),
      description: 'Popular residential area in Mekelle',
    ),
    TigrayLocation(
      id: 'mekelle_adi_haki',
      name: 'Adi Haki',
      city: 'Mekelle',
      category: 'neighborhood',
      coordinates: LatLng(13.4900, 39.4800),
      description: 'Central neighborhood in Mekelle',
    ),
    TigrayLocation(
      id: 'mekelle_quiha',
      name: 'Quiha',
      city: 'Mekelle',
      category: 'neighborhood',
      coordinates: LatLng(13.5150, 39.4900),
      description: 'Quiha area near university',
    ),
    TigrayLocation(
      id: 'mekelle_kedamay_weyane',
      name: 'Kedamay Weyane',
      city: 'Mekelle',
      category: 'neighborhood',
      coordinates: LatLng(13.4950, 39.4700),
      description: 'Central square and commercial area',
    ),
    TigrayLocation(
      id: 'mekelle_ayder',
      name: 'Ayder',
      city: 'Mekelle',
      category: 'neighborhood',
      coordinates: LatLng(13.4650, 39.4650),
      description: 'Area around Ayder Hospital',
    ),

    // Key Places
    TigrayLocation(
      id: 'mekelle_airport',
      name: 'Alula Aba Nega Airport',
      city: 'Mekelle',
      category: 'transport',
      coordinates: LatLng(13.4674, 39.5336),
      description: 'Mekelle International Airport',
    ),
    TigrayLocation(
      id: 'ayder_hospital',
      name: 'Ayder Comprehensive Specialized Hospital',
      city: 'Mekelle',
      category: 'hospital',
      coordinates: LatLng(13.4641, 39.4639),
      description: 'Major referral hospital in Tigray',
    ),
    TigrayLocation(
      id: 'mekelle_university',
      name: 'Mekelle University',
      city: 'Mekelle',
      category: 'education',
      coordinates: LatLng(13.4833, 39.4833),
      description: 'Main campus of Mekelle University',
    ),
    TigrayLocation(
      id: 'mekelle_bus_station',
      name: 'Mekelle Bus Station',
      city: 'Mekelle',
      category: 'transport',
      coordinates: LatLng(13.4950, 39.4750),
      description: 'Main bus terminal in Mekelle',
    ),
    TigrayLocation(
      id: 'yohannes_hotel',
      name: 'Yohannes IV Monument',
      city: 'Mekelle',
      category: 'landmark',
      coordinates: LatLng(13.4967, 39.4753),
      description: 'Historical monument in city center',
    ),
    TigrayLocation(
      id: 'mekelle_market',
      name: 'Mekelle Central Market',
      city: 'Mekelle',
      category: 'shopping',
      coordinates: LatLng(13.4920, 39.4730),
      description: 'Main marketplace in Mekelle',
    ),
  ];

  // Adigrat Locations
  static const List<TigrayLocation> adigratLocations = [
    TigrayLocation(
      id: 'adigrat_downtown',
      name: 'Adigrat Downtown',
      city: 'Adigrat',
      category: 'neighborhood',
      coordinates: LatLng(14.2769, 39.4619),
      description: 'City center of Adigrat',
    ),
    TigrayLocation(
      id: 'adigrat_agazi',
      name: 'Agazi',
      city: 'Adigrat',
      category: 'neighborhood',
      coordinates: LatLng(14.2800, 39.4650),
      description: 'Residential area in Adigrat',
    ),
    TigrayLocation(
      id: 'adigrat_edaga_selam',
      name: 'Edaga Selam',
      city: 'Adigrat',
      category: 'neighborhood',
      coordinates: LatLng(14.2750, 39.4600),
      description: 'Neighborhood in Adigrat',
    ),
    TigrayLocation(
      id: 'adigrat_bus_station',
      name: 'Adigrat Bus Station',
      city: 'Adigrat',
      category: 'transport',
      coordinates: LatLng(14.2770, 39.4620),
      description: 'Main bus terminal in Adigrat',
    ),
    TigrayLocation(
      id: 'adigrat_hospital',
      name: 'Adigrat Hospital',
      city: 'Adigrat',
      category: 'hospital',
      coordinates: LatLng(14.2780, 39.4610),
      description: 'Main hospital in Adigrat',
    ),
  ];

  // All locations combined
  static List<TigrayLocation> get allLocations {
    return [...mekelleLocations, ...adigratLocations];
  }

  // Popular locations (for quick access)
  static List<TigrayLocation> get popularLocations {
    return allLocations
        .where((loc) =>
            loc.category == 'transport' ||
            loc.category == 'hospital' ||
            loc.category == 'landmark' ||
            loc.category == 'education')
        .toList();
  }

  // Search locations by name
  static List<TigrayLocation> searchLocations(String query) {
    if (query.isEmpty) return popularLocations;

    final lowerQuery = query.toLowerCase();
    return allLocations
        .where((loc) =>
            loc.name.toLowerCase().contains(lowerQuery) ||
            loc.city.toLowerCase().contains(lowerQuery) ||
            (loc.description?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }

  // Get locations by category
  static List<TigrayLocation> getLocationsByCategory(String category) {
    return allLocations.where((loc) => loc.category == category).toList();
  }

  // Get locations by city
  static List<TigrayLocation> getLocationsByCity(String city) {
    return allLocations.where((loc) => loc.city == city).toList();
  }

  // Find closest location to given coordinates
  static TigrayLocation? findClosestLocation(LatLng point) {
    if (allLocations.isEmpty) return null;

    const Distance distance = Distance();
    TigrayLocation? closest;
    double minDistance = double.infinity;

    for (final location in allLocations) {
      final dist = distance.as(
        LengthUnit.Meter,
        point,
        location.coordinates,
      );

      if (dist < minDistance) {
        minDistance = dist;
        closest = location;
      }
    }

    return closest;
  }
}

/// Saved place model for user's frequently used locations
class SavedPlace {
  final String id;
  final String name;
  final String address;
  final LatLng coordinates;
  final String icon; // 'home', 'work', 'favorite'

  const SavedPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.coordinates,
    required this.icon,
  });
}

/// Sample saved places (would come from user profile in real app)
class SampleSavedPlaces {
  static const List<SavedPlace> defaultSavedPlaces = [
    SavedPlace(
      id: 'home',
      name: 'Home',
      address: 'Hawelti, Mekelle',
      coordinates: LatLng(13.4833, 39.4750),
      icon: 'home',
    ),
    SavedPlace(
      id: 'work',
      name: 'Work',
      address: 'Kedamay Weyane, Mekelle',
      coordinates: LatLng(13.4950, 39.4700),
      icon: 'work',
    ),
  ];
}

/// Recent trip model
class RecentTrip {
  final String id;
  final String destinationName;
  final String destinationAddress;
  final LatLng destinationCoordinates;
  final DateTime timestamp;

  const RecentTrip({
    required this.id,
    required this.destinationName,
    required this.destinationAddress,
    required this.destinationCoordinates,
    required this.timestamp,
  });
}

/// Sample recent trips
class SampleRecentTrips {
  static final List<RecentTrip> defaultRecentTrips = [
    RecentTrip(
      id: 'recent_1',
      destinationName: 'Ayder Hospital',
      destinationAddress: 'Ayder, Mekelle',
      destinationCoordinates: const LatLng(13.4641, 39.4639),
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    RecentTrip(
      id: 'recent_2',
      destinationName: 'Mekelle University',
      destinationAddress: 'Quiha, Mekelle',
      destinationCoordinates: const LatLng(13.4833, 39.4833),
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
}
