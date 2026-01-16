import 'package:latlong2/latlong.dart';
import 'construction.dart';

/// Modèle 3D d'un bâtiment pour la visualisation
class Building3DModel {
  /// Identifiant unique du bâtiment
  final int? id;
  
  /// Nom ou adresse du bâtiment
  final String name;
  
  /// Type de construction (Résidentiel, Commercial, etc.)
  final String type;
  
  /// Points définissant l'emprise au sol du bâtiment
  final List<LatLng> footprint;
  
  /// Hauteur du bâtiment en mètres
  final double height;
  
  /// Nombre d'étages
  final int floors;
  
  /// Couleur du bâtiment (code hex)
  final String color;
  
  /// Type de toit ('flat', 'gable', 'hip', 'dome')
  final String roofType;
  
  /// Hauteur du toit en mètres (pour les toits non plats)
  final double roofHeight;
  
  /// Matériau des murs ('brick', 'concrete', 'glass', 'wood')
  final String wallMaterial;
  
  /// Matériau du toit ('tiles', 'metal', 'concrete', 'shingles')
  final String roofMaterial;
  
  /// Opacité du bâtiment (0.0 à 1.0)
  final double opacity;

  Building3DModel({
    this.id,
    required this.name,
    required this.type,
    required this.footprint,
    this.height = 10.0,
    this.floors = 3,
    this.color = '#808080',
    this.roofType = 'flat',
    this.roofHeight = 2.0,
    this.wallMaterial = 'concrete',
    this.roofMaterial = 'concrete',
    this.opacity = 1.0,
  });

  /// Crée un Building3DModel à partir d'une Construction existante
  factory Building3DModel.fromConstruction(
    Construction construction, {
    double? height,
    int? floors,
    String? roofType,
  }) {
    // Estimation de la hauteur basée sur le type
    final estimatedHeight = height ?? _estimateHeightByType(construction.type);
    final estimatedFloors = floors ?? (estimatedHeight / 3).ceil();
    
    return Building3DModel(
      id: construction.id,
      name: construction.adresse,
      type: construction.type,
      footprint: construction.getPolygonPoints(),
      height: estimatedHeight,
      floors: estimatedFloors,
      color: _getColorByType(construction.type),
      roofType: roofType ?? _getRoofTypeByBuilding(construction.type),
      wallMaterial: _getWallMaterialByType(construction.type),
      roofMaterial: _getRoofMaterialByType(construction.type),
    );
  }

  /// Estime la hauteur en fonction du type de bâtiment
  static double _estimateHeightByType(String type) {
    switch (type.toLowerCase()) {
      case 'résidentiel':
        return 9.0; // 3 étages
      case 'commercial':
        return 12.0; // 4 étages
      case 'industriel':
        return 8.0; // 2-3 étages, hauts plafonds
      case 'public':
        return 15.0; // 5 étages
      default:
        return 10.0;
    }
  }

  /// Obtient la couleur en fonction du type
  static String _getColorByType(String type) {
    switch (type.toLowerCase()) {
      case 'résidentiel':
        return '#E57373'; // Rouge clair
      case 'commercial':
        return '#64B5F6'; // Bleu clair
      case 'industriel':
        return '#FFB74D'; // Orange
      case 'public':
        return '#81C784'; // Vert clair
      default:
        return '#90A4AE'; // Gris bleu
    }
  }

  /// Détermine le type de toit selon le type de bâtiment
  static String _getRoofTypeByBuilding(String type) {
    switch (type.toLowerCase()) {
      case 'résidentiel':
        return 'gable'; // Toit à deux pentes
      case 'commercial':
        return 'flat'; // Toit plat
      case 'industriel':
        return 'flat'; // Toit plat
      case 'public':
        return 'hip'; // Toit à quatre pentes
      default:
        return 'flat';
    }
  }

  /// Détermine le matériau des murs
  static String _getWallMaterialByType(String type) {
    switch (type.toLowerCase()) {
      case 'résidentiel':
        return 'brick';
      case 'commercial':
        return 'glass';
      case 'industriel':
        return 'metal';
      case 'public':
        return 'concrete';
      default:
        return 'concrete';
    }
  }

  /// Détermine le matériau du toit
  static String _getRoofMaterialByType(String type) {
    switch (type.toLowerCase()) {
      case 'résidentiel':
        return 'tiles';
      case 'commercial':
        return 'concrete';
      case 'industriel':
        return 'metal';
      case 'public':
        return 'tiles';
      default:
        return 'concrete';
    }
  }

  /// Calcule le centre de l'emprise au sol
  LatLng get center {
    if (footprint.isEmpty) return const LatLng(0, 0);
    
    double sumLat = 0, sumLng = 0;
    for (var point in footprint) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }
    return LatLng(sumLat / footprint.length, sumLng / footprint.length);
  }

  /// Calcule l'aire approximative en m²
  double get area {
    if (footprint.length < 3) return 0;
    
    double sum = 0;
    for (int i = 0; i < footprint.length; i++) {
      final j = (i + 1) % footprint.length;
      sum += footprint[i].longitude * footprint[j].latitude;
      sum -= footprint[j].longitude * footprint[i].latitude;
    }
    
    // Conversion approximative en m² (dépend de la latitude)
    final latRad = center.latitude * 3.14159 / 180;
    final metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng = 111320.0 * (1 - 0.00669438 * (latRad * latRad).abs()).abs();
    
    return (sum.abs() / 2) * metersPerDegreeLat * metersPerDegreeLng;
  }

  /// Volume approximatif du bâtiment en m³
  double get volume => area * height;

  /// Copie avec modifications
  Building3DModel copyWith({
    int? id,
    String? name,
    String? type,
    List<LatLng>? footprint,
    double? height,
    int? floors,
    String? color,
    String? roofType,
    double? roofHeight,
    String? wallMaterial,
    String? roofMaterial,
    double? opacity,
  }) {
    return Building3DModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      footprint: footprint ?? this.footprint,
      height: height ?? this.height,
      floors: floors ?? this.floors,
      color: color ?? this.color,
      roofType: roofType ?? this.roofType,
      roofHeight: roofHeight ?? this.roofHeight,
      wallMaterial: wallMaterial ?? this.wallMaterial,
      roofMaterial: roofMaterial ?? this.roofMaterial,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  String toString() {
    return 'Building3DModel{id: $id, name: $name, height: ${height}m, floors: $floors}';
  }
}
