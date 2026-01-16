import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/tour.dart';

/// Service de routage utilisant OSRM (Open Source Routing Machine)
/// 
/// Fournit :
/// - Calcul d'itinéraires entre points
/// - Optimisation de tournées (TSP)
/// - Instructions de navigation
class RoutingService {
  // OSRM public server (utiliser votre propre serveur en production)
  static const String _baseUrl = 'https://router.project-osrm.org';
  
  /// Calculer un itinéraire entre deux points
  static Future<RouteSegment?> getRoute(LatLng start, LatLng end) async {
    try {
      final url = '$_baseUrl/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${end.longitude},${end.latitude}'
          '?overview=full&geometries=geojson&steps=true';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;
          
          // Convertir les coordonnées GeoJSON en LatLng
          List<LatLng> polylinePoints = geometry
              .map<LatLng>((coord) => LatLng(
                    coord[1].toDouble(),
                    coord[0].toDouble(),
                  ))
              .toList();

          // Extraire les instructions
          List<RouteInstruction> instructions = [];
          if (route['legs'] != null && route['legs'].isNotEmpty) {
            final steps = route['legs'][0]['steps'] as List;
            instructions = steps
                .map<RouteInstruction>((step) => RouteInstruction.fromOSRM(step))
                .toList();
          }

          return RouteSegment(
            start: start,
            end: end,
            polylinePoints: polylinePoints,
            distanceMeters: (route['distance'] as num).toDouble(),
            durationSeconds: (route['duration'] as num).toDouble(),
            instructions: instructions,
          );
        }
      }
      return null;
    } catch (e) {
      print('Erreur de routing: $e');
      return null;
    }
  }

  /// Calculer un itinéraire passant par plusieurs points
  static Future<List<RouteSegment>> getMultiPointRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return [];
    
    List<RouteSegment> segments = [];
    
    for (int i = 0; i < waypoints.length - 1; i++) {
      final segment = await getRoute(waypoints[i], waypoints[i + 1]);
      if (segment != null) {
        segments.add(segment);
      }
    }
    
    return segments;
  }

  /// Optimiser l'ordre des stops (algorithme du plus proche voisin)
  /// 
  /// C'est un algorithme glouton simple pour le TSP :
  /// - Commencer par la position actuelle
  /// - Aller au point non visité le plus proche
  /// - Répéter jusqu'à avoir visité tous les points
  static List<TourStop> optimizeRoute(LatLng startPosition, List<TourStop> stops) {
    if (stops.length <= 1) return stops;
    
    List<TourStop> optimized = [];
    List<TourStop> remaining = List.from(stops);
    LatLng currentPosition = startPosition;
    
    while (remaining.isNotEmpty) {
      // Trouver le stop le plus proche
      TourStop? nearest;
      double minDistance = double.infinity;
      
      for (var stop in remaining) {
        final distance = _calculateDistance(currentPosition, stop.position);
        if (distance < minDistance) {
          minDistance = distance;
          nearest = stop;
        }
      }
      
      if (nearest != null) {
        optimized.add(nearest.copyWith(orderIndex: optimized.length));
        remaining.remove(nearest);
        currentPosition = nearest.position;
      }
    }
    
    return optimized;
  }

  /// Optimiser avec OSRM Trip API (meilleure optimisation mais nécessite connexion)
  static Future<List<TourStop>?> optimizeRouteOSRM(
    LatLng startPosition, 
    List<TourStop> stops,
  ) async {
    if (stops.length <= 1) return stops;
    
    try {
      // Construire les coordonnées pour l'API
      StringBuffer coords = StringBuffer();
      coords.write('${startPosition.longitude},${startPosition.latitude}');
      
      for (var stop in stops) {
        coords.write(';${stop.position.longitude},${stop.position.latitude}');
      }
      
      final url = '$_baseUrl/trip/v1/driving/${coords.toString()}'
          '?source=first&roundtrip=false';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && data['waypoints'] != null) {
          final waypoints = data['waypoints'] as List;
          
          // Réordonner les stops selon l'optimisation OSRM
          // Le premier waypoint est notre position de départ, donc on l'ignore
          List<TourStop> optimized = [];
          
          for (int i = 1; i < waypoints.length; i++) {
            final waypointIndex = waypoints[i]['waypoint_index'] - 1;
            if (waypointIndex >= 0 && waypointIndex < stops.length) {
              optimized.add(stops[waypointIndex].copyWith(
                orderIndex: optimized.length,
              ));
            }
          }
          
          return optimized;
        }
      }
      
      // Fallback vers l'algorithme local
      return optimizeRoute(startPosition, stops);
    } catch (e) {
      print('Erreur optimisation OSRM: $e');
      // Fallback vers l'algorithme local
      return optimizeRoute(startPosition, stops);
    }
  }

  /// Calculer la distance entre deux points (formule Haversine)
  static double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000; // Rayon de la Terre en mètres
    
    final lat1 = p1.latitude * math.pi / 180;
    final lat2 = p2.latitude * math.pi / 180;
    final deltaLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final deltaLng = (p2.longitude - p1.longitude) * math.pi / 180;
    
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Calculer la distance totale d'une tournée
  static double calculateTotalDistance(List<TourStop> stops) {
    if (stops.length < 2) return 0;
    
    double total = 0;
    for (int i = 0; i < stops.length - 1; i++) {
      total += _calculateDistance(stops[i].position, stops[i + 1].position);
    }
    return total;
  }

  /// Estimer le temps de trajet total (en secondes)
  /// Basé sur une vitesse moyenne de 30 km/h en zone urbaine
  static double estimateTotalDuration(List<TourStop> stops) {
    final distance = calculateTotalDistance(stops);
    const averageSpeed = 30 * 1000 / 3600; // 30 km/h en m/s
    return distance / averageSpeed;
  }

  /// Formater la distance
  static String formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toInt()} m';
  }

  /// Formater la durée
  static String formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}min';
    }
    return '$minutes min';
  }

  /// Obtenir l'icône de direction selon le type de manœuvre
  static String getDirectionIcon(String type) {
    switch (type) {
      case 'turn':
        return '↪️';
      case 'new name':
        return '➡️';
      case 'depart':
        return '🚀';
      case 'arrive':
        return '📍';
      case 'merge':
        return '🔀';
      case 'on ramp':
        return '⬆️';
      case 'off ramp':
        return '⬇️';
      case 'fork':
        return '🔱';
      case 'end of road':
        return '🛑';
      case 'continue':
        return '⬆️';
      case 'roundabout':
        return '🔄';
      case 'rotary':
        return '🔄';
      case 'roundabout turn':
        return '🔄';
      case 'notification':
        return 'ℹ️';
      default:
        return '➡️';
    }
  }
}
