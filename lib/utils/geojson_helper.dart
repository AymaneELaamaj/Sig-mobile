import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// Classe utilitaire pour la gestion des GeoJSON
/// Gère la conversion, validation et calculs géométriques des polygones
class GeoJsonHelper {
  
  /// Convertit une liste de points LatLng en GeoJSON Polygon
  /// Le premier et dernier point sont automatiquement identiques (polygone fermé)
  static String pointsToGeoJson(List<LatLng> points) {
    if (points.length < 3) {
      throw ArgumentError('Un polygone doit avoir au moins 3 points');
    }

    // Créer les coordonnées au format GeoJSON [longitude, latitude]
    List<List<double>> coordinates = points.map((point) {
      return [point.longitude, point.latitude];
    }).toList();

    // Fermer le polygone (premier point = dernier point)
    if (coordinates.first[0] != coordinates.last[0] ||
        coordinates.first[1] != coordinates.last[1]) {
      coordinates.add([coordinates.first[0], coordinates.first[1]]);
    }

    // Structure GeoJSON
    Map<String, dynamic> geoJson = {
      "type": "Polygon",
      "coordinates": [coordinates]
    };

    return jsonEncode(geoJson);
  }

  /// Convertit un GeoJSON Polygon en liste de points LatLng
  static List<LatLng> geoJsonToPoints(String geoJsonString) {
    try {
      Map<String, dynamic> geoJson = jsonDecode(geoJsonString);
      
      // Vérifier le type
      if (geoJson['type'] != 'Polygon') {
        // Support pour l'ancien format (simple "lat,lng")
        if (geoJsonString.contains(',') && !geoJsonString.contains('{')) {
          final parts = geoJsonString.split(',');
          if (parts.length == 2) {
            return [LatLng(double.parse(parts[0]), double.parse(parts[1]))];
          }
        }
        throw FormatException('Type GeoJSON non supporté: ${geoJson['type']}');
      }

      List<dynamic> coordinates = geoJson['coordinates'][0];
      
      // Convertir en LatLng (inverser car GeoJSON = [lng, lat])
      List<LatLng> points = coordinates.map<LatLng>((coord) {
        return LatLng(coord[1].toDouble(), coord[0].toDouble());
      }).toList();

      // Retirer le dernier point s'il est identique au premier (polygone fermé)
      if (points.length > 1 &&
          points.first.latitude == points.last.latitude &&
          points.first.longitude == points.last.longitude) {
        points.removeLast();
      }

      return points;
    } catch (e) {
      // Fallback pour l'ancien format "lat,lng"
      if (geoJsonString.contains(',') && !geoJsonString.contains('{')) {
        final parts = geoJsonString.split(',');
        if (parts.length == 2) {
          return [LatLng(double.parse(parts[0]), double.parse(parts[1]))];
        }
      }
      throw FormatException('Erreur de parsing GeoJSON: $e');
    }
  }

  /// Calcule le centroïde (centre géométrique) d'un polygone
  static LatLng calculateCentroid(List<LatLng> points) {
    if (points.isEmpty) {
      throw ArgumentError('La liste de points ne peut pas être vide');
    }

    if (points.length == 1) {
      return points.first;
    }

    double sumLat = 0;
    double sumLng = 0;

    for (var point in points) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }

    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  /// Calcule le centroïde depuis un GeoJSON string
  static LatLng getCentroidFromGeoJson(String geoJsonString) {
    List<LatLng> points = geoJsonToPoints(geoJsonString);
    return calculateCentroid(points);
  }

  /// Vérifie si un polygone est valide (minimum 3 points)
  static bool isValidPolygon(List<LatLng> points) {
    return points.length >= 3;
  }

  /// Vérifie si un polygone est auto-intersectant (simplifié)
  /// Retourne true si le polygone s'auto-intersecte
  static bool isSelfIntersecting(List<LatLng> points) {
    if (points.length < 4) return false;

    // Algorithme simplifié : vérifier si deux segments non adjacents se croisent
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 2; j < points.length; j++) {
        // Ne pas comparer les segments adjacents
        if (i == 0 && j == points.length - 1) continue;

        if (_segmentsIntersect(
          points[i],
          points[(i + 1) % points.length],
          points[j],
          points[(j + 1) % points.length],
        )) {
          return true;
        }
      }
    }
    return false;
  }

  /// Vérifie si deux segments se croisent
  static bool _segmentsIntersect(LatLng p1, LatLng p2, LatLng p3, LatLng p4) {
    double d1 = _direction(p3, p4, p1);
    double d2 = _direction(p3, p4, p2);
    double d3 = _direction(p1, p2, p3);
    double d4 = _direction(p1, p2, p4);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    return false;
  }

  /// Calcule le produit vectoriel pour déterminer la direction
  static double _direction(LatLng p1, LatLng p2, LatLng p3) {
    return (p3.longitude - p1.longitude) * (p2.latitude - p1.latitude) -
        (p2.longitude - p1.longitude) * (p3.latitude - p1.latitude);
  }

  /// Calcule l'aire d'un polygone (en mètres carrés approximatifs)
  static double calculateArea(List<LatLng> points) {
    if (points.length < 3) return 0;

    double area = 0;
    int j = points.length - 1;

    for (int i = 0; i < points.length; i++) {
      area += (points[j].longitude + points[i].longitude) *
          (points[j].latitude - points[i].latitude);
      j = i;
    }

    // Conversion approximative en mètres carrés
    // 1 degré de latitude ≈ 111 km
    return (area.abs() / 2) * 111000 * 111000;
  }

  /// Calcule les limites (bounding box) d'un polygone
  static Map<String, double> getBounds(List<LatLng> points) {
    if (points.isEmpty) {
      throw ArgumentError('La liste de points ne peut pas être vide');
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    };
  }
}
