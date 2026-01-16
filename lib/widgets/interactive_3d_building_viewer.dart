import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart' hide Material;

import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;
import '../models/building_3d_model.dart';

/// Widget de visualisation 3D interactive d'un bâtiment
/// 
/// Permet de :
/// - Visualiser un bâtiment en 3D
/// - Tourner et zoomer avec les gestes
/// - Afficher les informations du bâtiment
/// - Changer les couleurs et matériaux
class Interactive3DBuildingViewer extends StatefulWidget {
  /// Modèle 3D du bâtiment à afficher
  final Building3DModel building;
  
  /// Afficher les contrôles (rotation, zoom)
  final bool showControls;
  
  /// Afficher les informations du bâtiment
  final bool showInfo;
  
  /// Couleur de fond
  final Color backgroundColor;
  
  /// Callback quand le bâtiment est touché
  final VoidCallback? onTap;

  const Interactive3DBuildingViewer({
    super.key,
    required this.building,
    this.showControls = true,
    this.showInfo = true,
    this.backgroundColor = const Color(0xFF1A1A2E),
    this.onTap,
  });

  @override
  State<Interactive3DBuildingViewer> createState() => _Interactive3DBuildingViewerState();
}

class _Interactive3DBuildingViewerState extends State<Interactive3DBuildingViewer>
    with SingleTickerProviderStateMixin {
  
  // Scène et objets 3D
  late Scene _scene;
  Object? _buildingObject;
  Object? _groundObject;
  
  // Contrôles de rotation
  double _rotationX = 25.0; // Inclinaison
  double _rotationY = 45.0; // Rotation horizontale
  double _zoom = 1.0;
  
  // Animation
  late AnimationController _animationController;
  bool _autoRotate = false;
  
  // Mode wireframe
  bool _wireframe = false;
  
  // Étage sélectionné pour highlight
  int? _selectedFloor;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_onAnimationTick);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    if (_autoRotate && mounted) {
      setState(() {
        _rotationY += 0.5;
        if (_rotationY > 360) _rotationY -= 360;
      });
    }
  }

  /// Initialise la scène 3D
  void _onSceneCreated(Scene scene) {
    print('=== 3D Viewer: Scene created ===');
    _scene = scene;
    
    // Configuration de la caméra
    scene.camera.position.setFrom(vm.Vector3(0, 5, 10));
    scene.camera.target.setFrom(vm.Vector3(0, 2, 0));
    print('Camera configured: position=${scene.camera.position}, target=${scene.camera.target}');
    
    // Configuration de la lumière
    scene.light.position.setFrom(vm.Vector3(5, 10, 5));
    scene.light.setColor(Colors.white, 1.0, 1.0, 1.0); // RGB blanc, ambient, diffuse, specular
    print('Light configured: position=${scene.light.position}');
    
    // Créer le bâtiment
    print('Building data: name=${widget.building.name}, footprint points=${widget.building.footprint.length}, height=${widget.building.height}');
    try {
      _buildingObject = _generateBuildingMesh();
      if (_buildingObject != null) {
        scene.world.add(_buildingObject!);
        print('Building object added to scene: vertices=${(_buildingObject!.mesh as Mesh).vertices.length}');
      } else {
        print('ERROR: Building object is null!');
      }
    } catch (e, stack) {
      print('ERROR generating building mesh: $e');
      print('Stack trace: $stack');
    }
    
    // Créer le sol
    try {
      _groundObject = _generateGroundMesh();
      if (_groundObject != null) {
        scene.world.add(_groundObject!);
        print('Ground object added to scene');
      }
    } catch (e, stack) {
      print('ERROR generating ground mesh: $e');
      print('Stack trace: $stack');
    }
    
    // Appliquer la rotation initiale
    _updateRotation();
    print('=== Scene setup complete ===');
  }

  /// Génère le mesh 3D du bâtiment
  Object _generateBuildingMesh() {
    final mesh = Mesh();
    final building = widget.building;
    
    // Normaliser les coordonnées pour la visualisation 3D
    final normalizedPoints = _normalizeFootprint(building.footprint);
    final n = normalizedPoints.length;
    
    if (n < 3) {
      // Créer un cube par défaut si pas assez de points
      return _createDefaultCube();
    }
    
    // Calculer la hauteur normalisée (1 unité = 3m environ)
    final normalizedHeight = building.height / 3.0;
    
    // Générer les vertices
    final vertices = <vm.Vector3>[];
    final texcoords = <Offset>[];
    final colors = <Color>[];
    
    // Couleur du bâtiment
    final buildingColor = _parseColor(building.color);
    final roofColor = _darkenColor(buildingColor, 0.2);
    
    // Points du sol (y = 0)
    for (var point in normalizedPoints) {
      vertices.add(vm.Vector3(point.dx, 0, point.dy));
      texcoords.add(Offset(point.dx / 10 + 0.5, point.dy / 10 + 0.5));
      colors.add(buildingColor);
    }
    
    // Points du toit (y = hauteur)
    for (var point in normalizedPoints) {
      vertices.add(vm.Vector3(point.dx, normalizedHeight, point.dy));
      texcoords.add(Offset(point.dx / 10 + 0.5, point.dy / 10 + 0.5));
      colors.add(roofColor);
    }
    
    // Générer les faces (indices des triangles)
    final indices = <Polygon>[];
    
    // Murs (chaque segment = 2 triangles formant un quad)
    for (int i = 0; i < n; i++) {
      final next = (i + 1) % n;
      
      // Triangle 1 du mur
      indices.add(Polygon(i, next, i + n));
      // Triangle 2 du mur
      indices.add(Polygon(next, next + n, i + n));
    }
    
    // Sol (triangulation en éventail depuis le centre)
    if (n >= 3) {
      for (int i = 1; i < n - 1; i++) {
        indices.add(Polygon(0, i + 1, i));
      }
    }
    
    // Toit
    if (building.roofType == 'flat') {
      // Toit plat - même triangulation que le sol
      for (int i = 1; i < n - 1; i++) {
        indices.add(Polygon(n, n + i, n + i + 1));
      }
    } else {
      // Toit avec pointe (pour gable, hip, dome)
      _addRoofMesh(vertices, indices, normalizedPoints, normalizedHeight, building);
    }
    
    mesh.vertices = vertices;
    mesh.indices = indices;
    mesh.texcoords = texcoords;
    mesh.colors = colors;
    
    return Object(
      name: 'building_${building.id ?? 0}',
      mesh: mesh,
      backfaceCulling: true,
      lighting: true,
    );
  }

  /// Ajoute le mesh du toit selon le type
  void _addRoofMesh(
    List<vm.Vector3> vertices,
    List<Polygon> indices,
    List<Offset> normalizedPoints,
    double baseHeight,
    Building3DModel building,
  ) {
    final n = normalizedPoints.length;
    final roofHeight = building.roofHeight / 3.0;
    
    // Calculer le centre du toit
    double centerX = 0, centerZ = 0;
    for (var point in normalizedPoints) {
      centerX += point.dx;
      centerZ += point.dy;
    }
    centerX /= n;
    centerZ /= n;
    
    // Point au sommet du toit
    final peakIndex = vertices.length;
    vertices.add(vm.Vector3(centerX, baseHeight + roofHeight, centerZ));
    
    // Triangles du toit vers le sommet
    for (int i = 0; i < n; i++) {
      final next = (i + 1) % n;
      // Triangle de la pente du toit
      indices.add(Polygon(n + i, n + next, peakIndex));
    }
  }

  /// Génère le mesh du sol
  Object _generateGroundMesh() {
    final mesh = Mesh();
    
    // Sol carré de 20x20 unités
    const size = 20.0;
    
    mesh.vertices = [
      vm.Vector3(-size, -0.01, -size),
      vm.Vector3(size, -0.01, -size),
      vm.Vector3(size, -0.01, size),
      vm.Vector3(-size, -0.01, size),
    ];
    
    mesh.texcoords = [
      const Offset(0, 0),
      const Offset(1, 0),
      const Offset(1, 1),
      const Offset(0, 1),
    ];
    
    mesh.indices = [
      Polygon(0, 1, 2),
      Polygon(0, 2, 3),
    ];
    
    mesh.colors = [
      Colors.grey.shade600,
      Colors.grey.shade600,
      Colors.grey.shade600,
      Colors.grey.shade600,
    ];
    
    return Object(
      name: 'ground',
      mesh: mesh,
      backfaceCulling: false,
      lighting: true,
    );
  }

  /// Crée un cube par défaut quand pas de footprint valide
  Object _createDefaultCube() {
    final mesh = Mesh();
    
    // Vertices d'un cube
    mesh.vertices = [
      // Face avant
      vm.Vector3(-1, 0, 1), vm.Vector3(1, 0, 1),
      vm.Vector3(1, 2, 1), vm.Vector3(-1, 2, 1),
      // Face arrière
      vm.Vector3(-1, 0, -1), vm.Vector3(1, 0, -1),
      vm.Vector3(1, 2, -1), vm.Vector3(-1, 2, -1),
    ];
    
    mesh.indices = [
      // Avant
      Polygon(0, 1, 2), Polygon(0, 2, 3),
      // Arrière
      Polygon(5, 4, 7), Polygon(5, 7, 6),
      // Gauche
      Polygon(4, 0, 3), Polygon(4, 3, 7),
      // Droite
      Polygon(1, 5, 6), Polygon(1, 6, 2),
      // Dessus
      Polygon(3, 2, 6), Polygon(3, 6, 7),
      // Dessous
      Polygon(4, 5, 1), Polygon(4, 1, 0),
    ];
    
    mesh.colors = List.filled(8, _parseColor(widget.building.color));
    
    return Object(
      name: 'default_building',
      mesh: mesh,
      backfaceCulling: true,
      lighting: true,
    );
  }

  /// Normalise les coordonnées GPS pour l'affichage 3D
  List<Offset> _normalizeFootprint(List footprint) {
    if (footprint.isEmpty) return [];
    
    // Convertir en liste de points
    final points = footprint.map((p) {
      if (p is Offset) return p;
      // Supposer que c'est un LatLng
      return Offset(p.longitude, p.latitude);
    }).toList();
    
    // Trouver les limites
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    
    for (var point in points) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    
    // Centrer et mettre à l'échelle
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    final scale = rangeX > rangeY ? 5 / rangeX : 5 / rangeY;
    
    // Éviter division par zéro
    if (rangeX == 0 && rangeY == 0) {
      return [const Offset(0, 0)];
    }
    
    return points.map((p) {
      return Offset(
        (p.dx - centerX) * scale * 111320, // Conversion approx degrés -> mètres
        (p.dy - centerY) * scale * 111320,
      );
    }).toList();
  }

  /// Parse une couleur hex
  Color _parseColor(String hexColor) {
    try {
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }
      return Colors.grey;
    } catch (e) {
      return Colors.grey;
    }
  }

  /// Assombrit une couleur
  Color _darkenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  /// Met à jour la rotation de la scène
  void _updateRotation() {
    if (_buildingObject != null) {
      _buildingObject!.rotation.setValues(_rotationX, _rotationY, 0);
      _buildingObject!.updateTransform();
    }
    if (_groundObject != null) {
      _groundObject!.rotation.setValues(_rotationX, _rotationY, 0);
      _groundObject!.updateTransform();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          // Vue 3D
          Cube(
            onSceneCreated: _onSceneCreated,
            interactive: true,
          ),
          
          // Informations du bâtiment
          if (widget.showInfo) _buildInfoPanel(),
          
          // Contrôles
          if (widget.showControls) _buildControls(),
        ],
      ),
    );
  }

  /// Gestion du zoom et de la rotation
  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Gérer la rotation si l'utilisateur fait glisser avec un seul doigt
      if (details.scale == 1.0) {
        _rotationY += details.focalPointDelta.dx * 0.5;
        _rotationX += details.focalPointDelta.dy * 0.5;
        _rotationX = _rotationX.clamp(-90, 90);
        _updateRotation();
      } else {
        // Gérer le zoom si l'utilisateur pince
        _zoom = (_zoom * details.scale).clamp(0.5, 3.0);
      }
    });
  }

  /// Panneau d'informations
  Widget _buildInfoPanel() {
    final building = widget.building;
    
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              building.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.category, 'Type', building.type),
            _buildInfoRow(Icons.height, 'Hauteur', '${building.height.toStringAsFixed(1)} m'),
            _buildInfoRow(Icons.layers, 'Étages', '${building.floors}'),
            _buildInfoRow(Icons.square_foot, 'Surface', '${building.area.toStringAsFixed(1)} m²'),
            _buildInfoRow(Icons.view_in_ar, 'Volume', '${building.volume.toStringAsFixed(0)} m³'),
          ],
        ),
      ),
    );
  }

  /// Ligne d'information
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Contrôles de la vue 3D
  Widget _buildControls() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rotation automatique
          _buildControlButton(
            icon: _autoRotate ? Icons.pause : Icons.play_arrow,
            onPressed: () {
              setState(() {
                _autoRotate = !_autoRotate;
                if (_autoRotate) {
                  _animationController.repeat();
                } else {
                  _animationController.stop();
                }
              });
            },
            tooltip: 'Auto-rotation',
          ),
          const SizedBox(height: 8),
          
          // Reset vue
          _buildControlButton(
            icon: Icons.refresh,
            onPressed: () {
              setState(() {
                _rotationX = 25.0;
                _rotationY = 45.0;
                _zoom = 1.0;
                _updateRotation();
              });
            },
            tooltip: 'Réinitialiser',
          ),
          const SizedBox(height: 8),
          
          // Wireframe
          _buildControlButton(
            icon: _wireframe ? Icons.grid_off : Icons.grid_on,
            onPressed: () {
              setState(() {
                _wireframe = !_wireframe;
              });
            },
            tooltip: 'Wireframe',
          ),
          const SizedBox(height: 8),
          
          // Zoom in
          _buildControlButton(
            icon: Icons.add,
            onPressed: () {
              setState(() {
                _zoom = (_zoom * 1.2).clamp(0.5, 3.0);
              });
            },
            tooltip: 'Zoom +',
          ),
          const SizedBox(height: 8),
          
          // Zoom out
          _buildControlButton(
            icon: Icons.remove,
            onPressed: () {
              setState(() {
                _zoom = (_zoom / 1.2).clamp(0.5, 3.0);
              });
            },
            tooltip: 'Zoom -',
          ),
        ],
      ),
    );
  }

  /// Bouton de contrôle
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

/// Dialog pour afficher le viewer 3D en plein écran
class Building3DViewerDialog extends StatelessWidget {
  final Building3DModel building;

  const Building3DViewerDialog({
    super.key,
    required this.building,
  });

  static Future<void> show(BuildContext context, Building3DModel building) {
    return showDialog(
      context: context,
      builder: (context) => Building3DViewerDialog(building: building),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          color: const Color(0xFF1A1A2E),
          child: Stack(
            children: [
              Interactive3DBuildingViewer(
                building: building,
                showControls: true,
                showInfo: true,
              ),
              
              // Bouton fermer
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget compact pour prévisualiser un bâtiment en 3D
class Building3DPreview extends StatelessWidget {
  final Building3DModel building;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const Building3DPreview({
    super.key,
    required this.building,
    this.width = 150,
    this.height = 150,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Building3DViewerDialog.show(context, building),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Interactive3DBuildingViewer(
                building: building,
                showControls: false,
                showInfo: false,
              ),
              
              // Badge 3D
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '3D',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              // Icône de zoom
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
