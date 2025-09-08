import 'dart:math';

class DistanceCalculator {
  // Calculate distance between two coordinates using Haversine formula
  static double calculateDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const double earthRadius = 6371; // Earth radius in kilometers

    double dLat = _degreesToRadians(endLat - startLat);
    double dLng = _degreesToRadians(endLng - startLng);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(startLat)) *
        cos(_degreesToRadians(endLat)) *
        sin(dLng / 2) *
        sin(dLng / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    return distance;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }

  // Calculate estimated travel time (rough estimate)
  static String estimateTravelTime(double distanceKm, {String vehicleType = 'car'}) {
    double averageSpeed;
    
    switch (vehicleType) {
      case 'bike':
        averageSpeed = 25; // km/h in city traffic
        break;
      case 'threewheeler':
        averageSpeed = 30; // km/h
        break;
      case 'car':
        averageSpeed = 35; // km/h in city traffic
        break;
      case 'van':
        averageSpeed = 30; // km/h
        break;
      case 'bus':
        averageSpeed = 25; // km/h with stops
        break;
      default:
        averageSpeed = 30;
    }

    double timeInHours = distanceKm / averageSpeed;
    int minutes = (timeInHours * 60).round();

    if (minutes < 60) {
      return '$minutes min';
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours h';
      } else {
        return '$hours h $remainingMinutes min';
      }
    }
  }
}
