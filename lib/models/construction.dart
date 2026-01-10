import 'package:latlong2/latlong.dart';
import '../utils/geojson_helper.dart';

class Construction {
  final int? id;
  final String adresse;
  final String contact;
  final String type; // Ex: Résidentiel, Commercial
  final String geom; // Stockage des coordonnées au format GeoJSON

  Construction({
    this.id,
    required this.adresse,
    required this.contact,
    required this.type,
    required this.geom,
  });

  // Convertir un objet Construction en Map pour SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'adresse': adresse,
      'contact': contact,
      'type': type,
      'geom': geom,
    };
  }

  // Convertir une Map (venant de SQLite) en objet Construction
  factory Construction.fromMap(Map<String, dynamic> map) {
    return Construction(
      id: map['id'],
      adresse: map['adresse'],
      contact: map['contact'],
      type: map['type'],
      geom: map['geom'],
    );
  }

  /// Obtient le centroïde (centre) du polygone
  /// Utile pour centrer la carte sur cette construction
  LatLng getCentroid() {
    try {
      return GeoJsonHelper.getCentroidFromGeoJson(geom);
    } catch (e) {
      // Fallback pour l'ancien format "lat,lng"
      if (geom.contains(',') && !geom.contains('{')) {
        final parts = geom.split(',');
        if (parts.length == 2) {
          return LatLng(double.parse(parts[0]), double.parse(parts[1]));
        }
      }
      // Position par défaut (Casablanca)
      return const LatLng(33.5731, -7.5898);
    }
  }

  /// Obtient la liste des points du polygone
  List<LatLng> getPolygonPoints() {
    try {
      return GeoJsonHelper.geoJsonToPoints(geom);
    } catch (e) {
      // Fallback pour l'ancien format "lat,lng"
      if (geom.contains(',') && !geom.contains('{')) {
        final parts = geom.split(',');
        if (parts.length == 2) {
          return [LatLng(double.parse(parts[0]), double.parse(parts[1]))];
        }
      }
      return [];
    }
  }

  /// Vérifie si la géométrie est un polygone valide (>= 3 points)
  bool isValidPolygon() {
    try {
      List<LatLng> points = getPolygonPoints();
      return GeoJsonHelper.isValidPolygon(points);
    } catch (e) {
      return false;
    }
  }

  /// Vérifie si la géométrie est un simple point (ancien format)
  bool isPoint() {
    try {
      List<LatLng> points = getPolygonPoints();
      return points.length == 1;
    } catch (e) {
      return false;
    }
  }

  /// Calcule l'aire du polygone en m² (approximatif)
  double getArea() {
    try {
      List<LatLng> points = getPolygonPoints();
      return GeoJsonHelper.calculateArea(points);
    } catch (e) {
      return 0;
    }
  }

  /// Obtient les limites du polygone
  Map<String, double>? getBounds() {
    try {
      List<LatLng> points = getPolygonPoints();
      if (points.isEmpty) return null;
      return GeoJsonHelper.getBounds(points);
    } catch (e) {
      return null;
    }
  }

  /// Copie la construction avec des modifications
  Construction copyWith({
    int? id,
    String? adresse,
    String? contact,
    String? type,
    String? geom,
  }) {
    return Construction(
      id: id ?? this.id,
      adresse: adresse ?? this.adresse,
      contact: contact ?? this.contact,
      type: type ?? this.type,
      geom: geom ?? this.geom,
    );
  }

  @override
  String toString() {
    return 'Construction{id: $id, type: $type, adresse: $adresse}';
  }
}