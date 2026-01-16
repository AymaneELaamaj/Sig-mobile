import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../db/database_helper.dart';
import '../models/construction.dart';
import '../utils/geojson_helper.dart';
import '../utils/map_helper.dart';
import '../widgets/map_controls_widget.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/collapsible_legend_widget.dart';
import '../widgets/construction_popup.dart';
import '../widgets/gps_indicator_widget.dart';
import 'add_construction_screen.dart';
import 'construction_list_screen.dart';
import 'tour_planning_screen.dart';

/// Écran principal de la carte SIG
/// 
/// Affiche une carte interactive avec :
/// - Les constructions sous forme de polygones colorés
/// - Des marqueurs cliquables au centroïde
/// - Une barre de recherche avec filtres
/// - Des contrôles de carte (zoom, GPS, layers)
/// - Une légende collapsible
/// - La position GPS de l'utilisateur
class MapScreen extends StatefulWidget {
  /// Construction à centrer au démarrage (optionnel)
  final Construction? initialConstruction;

  const MapScreen({super.key, this.initialConstruction});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // ============================================
  // CONTRÔLEURS
  // ============================================
  
  /// Contrôleur de la carte flutter_map
  final MapController _mapController = MapController();

  // ============================================
  // DONNÉES
  // ============================================
  
  /// Liste complète des constructions
  List<Construction> _constructions = [];
  
  /// Liste filtrée des constructions (après recherche/filtres)
  List<Construction> _filteredConstructions = [];
  
  /// Construction actuellement sélectionnée
  Construction? _selectedConstruction;

  // ============================================
  // ÉTATS
  // ============================================
  
  /// Indique si les données sont en cours de chargement
  bool _isLoading = true;
  
  /// Indique si on localise l'utilisateur
  bool _isLocating = false;
  
  /// Indique si les marqueurs sont visibles
  bool _showMarkers = true;

  // ============================================
  // POSITION UTILISATEUR
  // ============================================
  
  /// Position GPS de l'utilisateur
  LatLng? _userPosition;
  
  /// Précision GPS en mètres
  double _gpsAccuracy = 20.0;

  // ============================================
  // FILTRES ET RECHERCHE
  // ============================================
  
  /// Filtre de type actif (null = tous les types)
  String? _activeTypeFilter;
  
  /// Texte de recherche actuel
  String _searchQuery = '';

  // ============================================
  // FOND DE CARTE
  // ============================================
  
  /// Type de fond de carte actuel
  MapLayerType _currentLayer = MapLayerType.standard;

  // ============================================
  // CONSTANTES
  // ============================================
  
  /// Map des couleurs par type de construction
  static const Map<String, Color> _typeColors = {
    'Résidentiel': Colors.red,
    'Commercial': Colors.blue,
    'Industriel': Colors.orange,
    'Public': Colors.green,
  };

  // ============================================
  // CYCLE DE VIE
  // ============================================

  @override
  void initState() {
    super.initState();
    _refreshConstructions();
    _getCurrentLocation();
  }

  // ============================================
  // MÉTHODES GPS
  // ============================================

  /// Obtenir la position GPS actuelle de l'utilisateur
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        return;
      }

      // Vérifier que le service GPS est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocating = false);
        _showError('Activez le service de localisation');
        return;
      }

      // Obtenir la position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
        _gpsAccuracy = position.accuracy;
        _isLocating = false;
      });
    } catch (e) {
      setState(() => _isLocating = false);
      debugPrint('Erreur GPS: $e');
    }
  }

  /// Recentrer la carte sur la position de l'utilisateur
  void _recenterOnUser() async {
    if (_userPosition != null) {
      _mapController.move(_userPosition!, 16);
      _showSuccess('Position actualisée');
    } else {
      await _getCurrentLocation();
      if (_userPosition != null) {
        _mapController.move(_userPosition!, 16);
      } else {
        _showError('Position GPS non disponible');
      }
    }
  }

  // ============================================
  // MÉTHODES DONNÉES
  // ============================================

  /// Charger toutes les constructions depuis la base de données
  Future<void> _refreshConstructions() async {
    setState(() => _isLoading = true);

    try {
      final data = await DatabaseHelper.instance.readAllConstructions();
      setState(() {
        _constructions = data;
        _applyFilters();
        _isLoading = false;
      });

      // Si une construction initiale est fournie, centrer dessus
      if (widget.initialConstruction != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _centerOnConstruction(widget.initialConstruction!);
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur lors du chargement des données');
    }
  }

  /// Appliquer les filtres (type + recherche) sur les constructions
  void _applyFilters() {
    List<Construction> results = _constructions;

    // Filtre par type
    if (_activeTypeFilter != null) {
      results = results.where((c) => c.type == _activeTypeFilter).toList();
    }

    // Filtre par recherche textuelle
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      results = results.where((c) {
        return c.adresse.toLowerCase().contains(query) ||
            c.contact.toLowerCase().contains(query) ||
            c.type.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredConstructions = results;
    });
  }

  /// Compter le nombre de constructions par type
  Map<String, int> _getTypeCounts() {
    Map<String, int> counts = {};
    for (var type in _typeColors.keys) {
      counts[type] = _filteredConstructions.where((c) => c.type == type).length;
    }
    return counts;
  }

  // ============================================
  // MÉTHODES CARTE
  // ============================================

  /// Centrer la carte sur une construction spécifique
  void _centerOnConstruction(Construction construction) {
    try {
      LatLng centroid = construction.getCentroid();
      double zoom = 17;
      
      // Ajuster le zoom si c'est un polygone
      if (construction.isValidPolygon()) {
        Map<String, double>? bounds = construction.getBounds();
        if (bounds != null) {
          zoom = MapHelper.calculateZoomForBounds(bounds, 400, 600);
        }
      }
      
      _mapController.move(centroid, zoom);
      setState(() {
        _selectedConstruction = construction;
      });
    } catch (e) {
      _showError('Erreur lors du centrage');
    }
  }

  /// Zoom avant sur la carte
  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  /// Zoom arrière sur la carte
  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  /// Afficher le sélecteur de fond de carte
  void _showLayerSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => LayerSelectorSheet(
        currentLayer: _currentLayer,
        onLayerChanged: (layer) {
          setState(() => _currentLayer = layer);
        },
      ),
    );
  }

  // ============================================
  // MÉTHODES ACTIONS
  // ============================================

  /// Afficher le popup d'information d'une construction
  void _showConstructionInfo(Construction construction) {
    setState(() => _selectedConstruction = construction);
    
    ConstructionPopup.show(
      context,
      construction: construction,
      onCenter: () => _centerOnConstruction(construction),
      onDelete: () => _deleteConstruction(construction),
    );
  }

  /// Supprimer une construction avec confirmation
  Future<void> _deleteConstruction(Construction construction) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('Confirmer la suppression'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voulez-vous vraiment supprimer cette construction ?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _getIconForType(construction.type),
                    color: _getColorForType(construction.type),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          construction.type,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          construction.adresse,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.delete(construction.id!);
        _showSuccess('Construction supprimée');
        _refreshConstructions();
        setState(() => _selectedConstruction = null);
      } catch (e) {
        _showError('Erreur lors de la suppression');
      }
    }
  }

  /// Ouvrir la liste des constructions
  Future<void> _openConstructionList() async {
    final result = await Navigator.push<Construction>(
      context,
      MaterialPageRoute(builder: (context) => const ConstructionListScreen()),
    );
    if (result != null) {
      _centerOnConstruction(result);
      _showConstructionInfo(result);
    }
  }

  /// Ajouter une nouvelle construction
  Future<void> _addConstruction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddConstructionScreen()),
    );
    if (result == true) {
      _refreshConstructions();
      _showSuccess('Construction ajoutée avec succès');
    }
  }

  // ============================================
  // MÉTHODES UTILITAIRES
  // ============================================

  Color _getColorForType(String type) {
    return _typeColors[type] ?? Colors.purple;
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Résidentiel':
        return Icons.home;
      case 'Commercial':
        return Icons.business;
      case 'Industriel':
        return Icons.factory;
      case 'Public':
        return Icons.account_balance;
      default:
        return Icons.place;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ============================================
  // CONSTRUCTION DES LAYERS CARTE
  // ============================================

  /// Construire les polygones pour le PolygonLayer
  List<Polygon> _buildPolygons() {
    if (!_showMarkers) return [];

    List<Polygon> polygons = [];
    for (var construction in _filteredConstructions) {
      try {
        List<LatLng> points = construction.getPolygonPoints();
        if (points.length >= 3) {
          Color color = _getColorForType(construction.type);
          bool isSelected = _selectedConstruction?.id == construction.id;

          polygons.add(
            Polygon(
              points: points,
              color: color.withOpacity(isSelected ? 0.5 : 0.3),
              borderColor: isSelected ? Colors.white : color,
              borderStrokeWidth: isSelected ? 4 : 2,
              isFilled: true,
            ),
          );
        }
      } catch (e) {
        continue;
      }
    }
    return polygons;
  }

  /// Construire les marqueurs pour le MarkerLayer
  List<Marker> _buildMarkers() {
    if (!_showMarkers) return [];

    List<Marker> markers = [];

    // Marqueur de position utilisateur (GPS)
    if (_userPosition != null) {
      markers.add(createGPSMarker(
        position: _userPosition!,
        accuracy: _gpsAccuracy,
      ));
    }

    // Marqueurs des constructions
    for (var construction in _filteredConstructions) {
      try {
        List<LatLng> points = construction.getPolygonPoints();
        Color color = _getColorForType(construction.type);
        bool isSelected = _selectedConstruction?.id == construction.id;

        // Point unique = marqueur simple
        if (points.length == 1) {
          markers.add(
            Marker(
              point: points.first,
              width: isSelected ? 55 : 45,
              height: isSelected ? 55 : 45,
              child: GestureDetector(
                onTap: () => _showConstructionInfo(construction),
                child: Icon(
                  Icons.location_on,
                  color: color,
                  size: isSelected ? 55 : 45,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 5,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // Polygone = marqueur au centroïde
        else if (points.length >= 3) {
          LatLng centroid = construction.getCentroid();
          markers.add(
            Marker(
              point: centroid,
              width: isSelected ? 44 : 36,
              height: isSelected ? 44 : 36,
              child: GestureDetector(
                onTap: () => _showConstructionInfo(construction),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withOpacity(0.9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: isSelected ? 8 : 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getIconForType(construction.type),
                    color: Colors.white,
                    size: isSelected ? 24 : 18,
                  ),
                ),
              ),
            ),
          );
        }
      } catch (e) {
        continue;
      }
    }
    return markers;
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      
      // AppBar avec titre et actions
      appBar: _buildAppBar(),
      
      // Corps de l'écran
      body: Column(
        children: [
          // Barre de recherche avec filtres
          MapSearchBar(
            onSearchChanged: (query) {
              setState(() => _searchQuery = query);
              _applyFilters();
            },
            onTypeFilterChanged: (type) {
              setState(() => _activeTypeFilter = type);
              _applyFilters();
            },
            resultCount: _filteredConstructions.length,
            totalCount: _constructions.length,
            activeTypeFilter: _activeTypeFilter,
            typeColors: _typeColors,
          ),
          
          // Carte
          Expanded(
            child: Stack(
              children: [
                // Carte FlutterMap
                _buildMap(),
                
                // Contrôles de carte (droite)
                Positioned(
                  right: 16,
                  top: 16,
                  child: MapControlsWidget(
                    onGpsPressed: _recenterOnUser,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                    onToggleMarkers: () {
                      setState(() => _showMarkers = !_showMarkers);
                    },
                    onLayerPressed: _showLayerSelector,
                    isLocating: _isLocating,
                    markersVisible: _showMarkers,
                  ),
                ),
                
                // Légende collapsible (bas droite)
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: CollapsibleLegendWidget(
                    typeColors: _typeColors,
                    typeCounts: _getTypeCounts(),
                    onTypeTap: (type) {
                      setState(() {
                        _activeTypeFilter = 
                            _activeTypeFilter == type ? null : type;
                      });
                      _applyFilters();
                    },
                  ),
                ),
                
                // Indicateur de chargement
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                
                // Message si aucune construction
                if (!_isLoading && _filteredConstructions.isEmpty)
                  _buildEmptyState(),
                
                // Compteur de constructions visibles (bas gauche)
                Positioned(
                  left: 16,
                  bottom: 20,
                  child: _buildVisibleCounter(),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // FAB amélioré
      floatingActionButton: EnhancedFAB(
        onAddPolygon: _addConstruction,
        onPlanTour: _openTourPlanning,
      ),
    );
  }

  /// Ouvrir l'écran de planification de tournée
  void _openTourPlanning() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TourPlanningScreen(),
      ),
    );
    
    // Rafraîchir les données si une tournée a été effectuée
    if (result == true) {
      _refreshConstructions();
    }
  }

  /// AppBar personnalisée
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      title: const Row(
        children: [
          Icon(Icons.map, color: Colors.blue),
          SizedBox(width: 10),
          Text(
            'SIG Mobile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        // Badge avec le nombre de constructions
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.list_alt),
              tooltip: 'Liste des constructions',
              onPressed: _openConstructionList,
            ),
            if (_constructions.isNotEmpty)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '${_constructions.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualiser',
          onPressed: _refreshConstructions,
        ),
      ],
    );
  }

  /// Carte FlutterMap
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(33.5731, -7.5898), // Casablanca
        initialZoom: 13.0,
        onTap: (tapPosition, point) {
          // Vérifier si on a cliqué sur un polygone
          for (var construction in _filteredConstructions) {
            if (MapHelper.isPointInGeoJson(point, construction.geom)) {
              _showConstructionInfo(construction);
              return;
            }
          }
          // Si non, désélectionner
          setState(() => _selectedConstruction = null);
        },
      ),
      children: [
        // Fond de carte
        TileLayer(
          urlTemplate: _currentLayer.tileUrl,
          userAgentPackageName: 'com.example.sig_mobile',
          subdomains: const ['a', 'b', 'c'],
        ),
        
        // Polygones des constructions
        PolygonLayer(polygons: _buildPolygons()),
        
        // Marqueurs (constructions + GPS)
        MarkerLayer(markers: _buildMarkers()),
      ],
    );
  }

  /// Compteur de constructions visibles
  Widget _buildVisibleCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            '${_filteredConstructions.length} construction${_filteredConstructions.length > 1 ? 's' : ''} visible${_filteredConstructions.length > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Message quand aucune construction n'est trouvée
  Widget _buildEmptyState() {
    final hasFilters = _searchQuery.isNotEmpty || _activeTypeFilter != null;
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters ? Icons.search_off : Icons.map_outlined,
                size: 50,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilters ? 'Aucun résultat' : 'Aucune construction',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hasFilters
                  ? 'Modifiez vos critères de recherche'
                  : 'Cliquez sur + pour ajouter votre première construction',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _activeTypeFilter = null;
                  });
                  _applyFilters();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Réinitialiser les filtres'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
