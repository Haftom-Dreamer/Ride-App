import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  static const String _baseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  // Get route between two points
  static Future<List<LatLng>?> getRoute(LatLng start, LatLng end) async {
    try {
      final url =
          '$_baseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;

        if (routes.isNotEmpty) {
          final route = routes.first;
          final geometry = route['geometry'];

          if (geometry != null && geometry['coordinates'] != null) {
            final coordinates = geometry['coordinates'] as List;
            return coordinates
                .map((coord) => LatLng(coord[1], coord[0]))
                .toList();
          }
        }
      }
    } catch (e) {
      print('Error getting route: $e');
    }

    return null;
  }

  // Get route with waypoints
  static Future<List<LatLng>?> getRouteWithWaypoints(
      List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;

    try {
      final coordinates = waypoints
          .map((point) => '${point.longitude},${point.latitude}')
          .join(';');
      final url = '$_baseUrl/$coordinates?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;

        if (routes.isNotEmpty) {
          final route = routes.first;
          final geometry = route['geometry'];

          if (geometry != null && geometry['coordinates'] != null) {
            final coordinates = geometry['coordinates'] as List;
            return coordinates
                .map((coord) => LatLng(coord[1], coord[0]))
                .toList();
          }
        }
      }
    } catch (e) {
      print('Error getting route with waypoints: $e');
    }

    return null;
  }

  // Calculate route distance and duration
  static Future<RouteInfo?> getRouteInfo(LatLng start, LatLng end) async {
    try {
      final url =
          '$_baseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=false';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;

        if (routes.isNotEmpty) {
          final route = routes.first;
          return RouteInfo(
            distance: route['distance']?.toDouble() ?? 0.0,
            duration: route['duration']?.toDouble() ?? 0.0,
          );
        }
      }
    } catch (e) {
      print('Error getting route info: $e');
    }

    return null;
  }
}

class RouteInfo {
  final double distance; // in meters
  final double duration; // in seconds

  RouteInfo({
    required this.distance,
    required this.duration,
  });

  String get distanceKm => (distance / 1000).toStringAsFixed(1);
  String get durationMinutes => (duration / 60).toStringAsFixed(0);
}

