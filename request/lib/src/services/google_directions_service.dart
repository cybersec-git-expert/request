import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

class GoogleDirectionsService {
  static const String _apiKey = 'AIzaSyAZhdbNcSuvrrNzyAYmdHy5kH9drDEHgw8';
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Get directions between two points
  static Future<List<LatLng>> getDirections({
    required LatLng origin,
    required LatLng destination,
    String travelMode = 'driving',
  }) async {
    try {
      final url = '$_baseUrl?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=$travelMode&'
          'key=$_apiKey';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final polylinePoints = route['overview_polyline']['points'];

          // Decode the polyline
          List<List<num>> coordinates = decodePolyline(polylinePoints);

          // Convert to LatLng points
          List<LatLng> points = coordinates
              .map((coord) => LatLng(coord[0].toDouble(), coord[1].toDouble()))
              .toList();

          return points;
        } else {
          print('Directions API error: ${data['status']}');
          return [];
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting directions: $e');
      return [];
    }
  }

  /// Get route information (distance, duration)
  static Future<Map<String, dynamic>> getRouteInfo({
    required LatLng origin,
    required LatLng destination,
    String travelMode = 'driving',
  }) async {
    try {
      final url = '$_baseUrl?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=$travelMode&'
          'key=$_apiKey';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          return {
            'distance': leg['distance']['value'], // in meters
            'duration': leg['duration']['value'], // in seconds
            'distanceText': leg['distance']['text'],
            'durationText': leg['duration']['text'],
          };
        } else {
          print('Directions API error: ${data['status']}');
          return {};
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('Error getting route info: $e');
      return {};
    }
  }
}
