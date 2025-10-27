import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  // Convert address to coordinates
  static Future<LatLng?> addressToCoordinates(String address) async {
    if (address.isEmpty) return null;

    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = '$_baseUrl/search?q=$encodedAddress&format=json&limit=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'RIDE_APP/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final result = results.first;
          return LatLng(
            double.parse(result['lat']),
            double.parse(result['lon']),
          );
        }
      }
    } catch (e) {
      print('Error geocoding address: $e');
    }

    return null;
  }

  // Convert coordinates to address
  static Future<String?> coordinatesToAddress(LatLng coordinates) async {
    try {
      final url =
          '$_baseUrl/reverse?lat=${coordinates.latitude}&lon=${coordinates.longitude}&format=json';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'RIDE_APP/1.0',
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['display_name'] ?? 'Unknown Location';
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
    }

    return null;
  }

  // Search for places with autocomplete
  static Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.length < 3) return [];

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url =
          '$_baseUrl/search?q=$encodedQuery&format=json&limit=5&addressdetails=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'RIDE_APP/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        return results
            .map((result) => PlaceSuggestion.fromJson(result))
            .toList();
      }
    } catch (e) {
      print('Error searching places: $e');
    }

    return [];
  }
}

class PlaceSuggestion {
  final String displayName;
  final LatLng coordinates;
  final String? city;
  final String? country;

  PlaceSuggestion({
    required this.displayName,
    required this.coordinates,
    this.city,
    this.country,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final address = json['address'] ?? {};
    return PlaceSuggestion(
      displayName: json['display_name'] ?? 'Unknown Location',
      coordinates: LatLng(
        double.parse(json['lat']),
        double.parse(json['lon']),
      ),
      city: address['city'] ?? address['town'] ?? address['village'],
      country: address['country'],
    );
  }
}

