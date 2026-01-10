import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/geojson_helper.dart';

/// Classe utilitaire pour les opérations de carte
/// Gère le centrage, zoom et calculs de bounds
class MapHelper {
  
  /// Calcule le niveau de zoom approprié pour afficher un polygone
  /// basé sur ses limites (bounding box)
  static double calculateZoomForBounds(Map<String, double> bounds, double mapWidth, double mapHeight) {
    double latDiff = bounds['maxLat']! - bounds['minLat']!;
    double lngDiff = bounds['maxLng']! - bounds['minLng']!;

    // Calcul simplifié du zoom
    // Plus la différence est grande, plus le zoom est faible
    double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    if (maxDiff < 0.001) return 18;
    if (maxDiff < 0.005) return 17;
    if (maxDiff < 0.01) return 16;
    if (maxDiff < 0.02) return 15;
    if (maxDiff < 0.05) return 14;
    if (maxDiff < 0.1) return 13;
    if (maxDiff < 0.2) return 12;
    if (maxDiff < 0.5) return 11;
    return 10;
  }

  /// Centre la carte sur un polygone donné (depuis GeoJSON)
  static void centerOnGeoJson(MapController mapController, String geoJson, {double? zoom}) {
    try {
      List<LatLng> points = GeoJsonHelper.geoJsonToPoints(geoJson);
      LatLng centroid = GeoJsonHelper.calculateCentroid(points);
      
      double targetZoom = zoom ?? 16;
      
      // Si pas de zoom spécifié, calculer en fonction des bounds
      if (zoom == null && points.length > 1) {
        Map<String, double> bounds = GeoJsonHelper.getBounds(points);
        targetZoom = calculateZoomForBounds(bounds, 400, 600); // Taille approximative
      }

      mapController.move(centroid, targetZoom);
    } catch (e) {
      print('Erreur lors du centrage sur GeoJSON: $e');
    }
  }

  /// Centre la carte sur un point spécifique avec animation
  static void centerOnPoint(MapController mapController, LatLng point, {double zoom = 16}) {
    mapController.move(point, zoom);
  }

  /// Centre la carte pour afficher tous les polygones
  static void fitAllPolygons(MapController mapController, List<String> geoJsonList) {
    if (geoJsonList.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;

    for (String geoJson in geoJsonList) {
      try {
        List<LatLng> points = GeoJsonHelper.geoJsonToPoints(geoJson);
        Map<String, double> bounds = GeoJsonHelper.getBounds(points);
        
        if (bounds['minLat']! < minLat) minLat = bounds['minLat']!;
        if (bounds['maxLat']! > maxLat) maxLat = bounds['maxLat']!;
        if (bounds['minLng']! < minLng) minLng = bounds['minLng']!;
        if (bounds['maxLng']! > maxLng) maxLng = bounds['maxLng']!;
      } catch (e) {
        continue;
      }
    }

    if (minLat == double.infinity) return;

    LatLng center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    double zoom = calculateZoomForBounds({
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    }, 400, 600);

    mapController.move(center, zoom);
  }

  /// Obtient les bounds pour un ensemble de polygones
  static LatLngBounds? getBoundsForPolygons(List<String> geoJsonList) {
    if (geoJsonList.isEmpty) return null;

    List<LatLng> allPoints = [];
    
    for (String geoJson in geoJsonList) {
      try {
        allPoints.addAll(GeoJsonHelper.geoJsonToPoints(geoJson));
      } catch (e) {
        continue;
      }
    }

    if (allPoints.isEmpty) return null;

    return LatLngBounds.fromPoints(allPoints);
  }

  /// Vérifie si un point est à l'intérieur d'un polygone
  /// Utilise l'algorithme du ray casting
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude > point.latitude) != (polygon[j].latitude > point.latitude) &&
          point.longitude < (polygon[j].longitude - polygon[i].longitude) * 
          (point.latitude - polygon[i].latitude) / 
          (polygon[j].latitude - polygon[i].latitude) + polygon[i].longitude) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Vérifie si un tap sur la carte touche un polygone
  static bool isPointInGeoJson(LatLng point, String geoJson) {
    try {
      List<LatLng> polygonPoints = GeoJsonHelper.geoJsonToPoints(geoJson);
      if (polygonPoints.length < 3) return false;
      return isPointInPolygon(point, polygonPoints);
    } catch (e) {
      return false;
    }
  }
}
