import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _apiKey = 'AIzaSyDTCzneUhpD2e-HinMiRhUGKlfX_D7fn9c'; // Replace with your API key

  static Future<String> getETA(LatLng origin, LatLng destination) async {
    try {
      final String url =
          '$_baseUrl?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['routes'].isNotEmpty) {
          // Get duration from the first route
          final duration = json['routes'][0]['legs'][0]['duration']['text'];
          return duration; // Returns format like "2 hours 30 mins"
        }
      }
      return '3 hours'; // Default fallback
    } catch (e) {
      print('Error fetching ETA: $e');
      return '3 hours'; // Fallback on error
    }
  }

  static Future<Map<String, dynamic>> getDirections(
      LatLng origin, LatLng destination) async {
    try {
      final String url =
          '$_baseUrl?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['routes'].isNotEmpty) {
          final route = json['routes'][0];
          final leg = route['legs'][0];

          return {
            'duration': leg['duration']['text'],
            'distance': leg['distance']['text'],
            'polylinePoints': route['overview_polyline']['points'],
          };
        }
      }
      return {'duration': '3 hours', 'distance': 'Unknown', 'polylinePoints': ''};
    } catch (e) {
      print('Error fetching directions: $e');
      return {'duration': '3 hours', 'distance': 'Unknown', 'polylinePoints': ''};
    }
  }
}