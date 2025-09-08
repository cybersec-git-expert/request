import 'dart:convert';
import 'package:http/http.dart' as http;

class GooglePlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static const String _apiKey = 'AIzaSyAZhdbNcSuvrrNzyAYmdHy5kH9drDEHgw8';
  static const String _placesV1 = 'https://places.googleapis.com/v1';

  // Search places by text input (optionally filter by country ISO code)
  static Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    String? countryCode,
  }) async {
    if (query.isEmpty) return [];

    // Try Places API (New) first
    try {
      final uri = Uri.parse('$_placesV1/places:autocomplete');
      final body = {
        'input': query,
        'languageCode': 'en',
        if (countryCode != null && countryCode.trim().isNotEmpty)
          'includedRegionCodes': [countryCode.toUpperCase()],
      };
      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        // Request only the fields we need
        'X-Goog-FieldMask':
            'suggestions.placePrediction.placeId,suggestions.placePrediction.structuredFormat.mainText,suggestions.placePrediction.structuredFormat.secondaryText',
      };

      final resp =
          await http.post(uri, headers: headers, body: jsonEncode(body));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is Map && data['suggestions'] is List) {
          final List suggestions = data['suggestions'];
          return suggestions
              .where((s) => (s['placePrediction'] ?? {}) is Map)
              .map<PlaceSuggestion>((s) {
            final pred = s['placePrediction'];
            final fmt = (pred['structuredFormat'] ?? {}) as Map;
            return PlaceSuggestion(
              placeId: pred['placeId'] ?? '', // e.g., 'places/ChIJ...'
              description:
                  '${fmt['mainText'] ?? ''}${fmt['secondaryText'] != null ? ', ${fmt['secondaryText']}' : ''}',
              mainText: fmt['mainText'] ?? '',
              secondaryText: fmt['secondaryText'] ?? '',
            );
          }).toList();
        }
      } else {
        print('Places v1 autocomplete failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      print('Places v1 autocomplete error: $e');
    }

    // Fallback to legacy Autocomplete if enabled
    try {
      final params = <String, String>{
        'input': query,
        'key': _apiKey,
        'language': 'en',
      };
      if (countryCode != null && countryCode.trim().isNotEmpty) {
        params['components'] = 'country:${countryCode.toUpperCase()}';
      }
      final url = Uri.parse('$_baseUrl/place/autocomplete/json')
          .replace(queryParameters: params);
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return (data['predictions'] as List)
              .map<PlaceSuggestion>((prediction) => PlaceSuggestion(
                    placeId: prediction['place_id'],
                    description: prediction['description'],
                    mainText:
                        prediction['structured_formatting']['main_text'] ?? '',
                    secondaryText: prediction['structured_formatting']
                            ['secondary_text'] ??
                        '',
                  ))
              .toList();
        } else {
          print(
              'Legacy autocomplete status: ${data['status']} ${data['error_message'] ?? ''}');
        }
      }
    } catch (e) {
      print('Legacy autocomplete error: $e');
    }

    return [];
  }

  // Get place details including coordinates
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    // Use Places API (New) if the ID looks like a Places resource name
    if (placeId.startsWith('places/')) {
      try {
        final uri = Uri.parse('$_placesV1/$placeId');
        final headers = {
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'id,formattedAddress,location',
        };
        final resp = await http.get(uri, headers: headers);
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final loc = (data['location'] ?? {}) as Map;
          return PlaceDetails(
            placeId: data['id']?.toString() ?? placeId,
            name: data['formattedAddress']?.toString() ?? '',
            formattedAddress: data['formattedAddress']?.toString() ?? '',
            latitude: (loc['latitude'] as num).toDouble(),
            longitude: (loc['longitude'] as num).toDouble(),
          );
        } else {
          print('Places v1 details failed: ${resp.statusCode} ${resp.body}');
        }
      } catch (e) {
        print('Places v1 details error: $e');
      }
    }

    // Fallback to legacy Details for legacy place_id
    try {
      final url = Uri.parse(
          '$_baseUrl/place/details/json?place_id=$placeId&fields=name,formatted_address,geometry&key=$_apiKey');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final geometry = result['geometry']['location'];
          return PlaceDetails(
            placeId: placeId,
            name: result['name'] ?? '',
            formattedAddress: result['formatted_address'] ?? '',
            latitude: (geometry['lat'] as num).toDouble(),
            longitude: (geometry['lng'] as num).toDouble(),
          );
        } else {
          print(
              'Legacy details status: ${data['status']} ${data['error_message'] ?? ''}');
        }
      }
    } catch (e) {
      print('Legacy details error: $e');
    }

    return null;
  }

  // Reverse geocoding - get address from coordinates
  static Future<String?> getAddressFromCoordinates(
      double lat, double lng) async {
    final url =
        Uri.parse('$_baseUrl/geocode/json?latlng=$lat,$lng&key=$_apiKey');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
    }

    return null;
  }

  // Forward geocoding - get coordinates from a free-form address
  static Future<PlaceDetails?> geocodeAddress(String address,
      {String? countryCode}) async {
    if (address.trim().isEmpty) return null;

    final params = <String, String>{
      'address': address,
      'key': _apiKey,
      'language': 'en',
    };
    if (countryCode != null && countryCode.trim().isNotEmpty) {
      params['components'] = 'country:${countryCode.toUpperCase()}';
    }

    final url =
        Uri.parse('$_baseUrl/geocode/json').replace(queryParameters: params);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final geometry = result['geometry']['location'];
          return PlaceDetails(
            placeId: (result['place_id'] ?? '').toString(),
            name: result['formatted_address'] ?? '',
            formattedAddress: result['formatted_address'] ?? '',
            latitude: (geometry['lat'] as num).toDouble(),
            longitude: (geometry['lng'] as num).toDouble(),
          );
        }
      }
    } catch (e) {
      print('Error forward geocoding: $e');
    }

    return null;
  }
}

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });
}
