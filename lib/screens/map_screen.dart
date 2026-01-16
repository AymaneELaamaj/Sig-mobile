import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import '../db/database_helper.dart';
import '../models/construction.dart';
import '../models/route_info.dart';
import '../utils/geojson_helper.dart';
import '../utils/map_helper.dart';
import '../utils/marker_clusterer.dart';
import '../services/routing_service.dart';
import '../widgets/map_controls_widget.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/collapsible_legend_widget.dart';
import '../widgets/construction_popup.dart';
import '../widgets/gps_indicator_widget.dart';
import '../widgets/route_panel_widget.dart';
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
  
  /// Niveau de zoom actuel pour le clustering
  double _currentZoom = 13.0;

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
  // ITINÉRAIRE
  // ============================================
  
  /// Information de l'itinéraire actuel (null si pas d'itinéraire)
  RouteInfo? _currentRoute;
  
  /// Mode de transport pour l'itinéraire
  TravelMode _travelMode = TravelMode.driving;
  
  /// Indique si un calcul d'itinéraire est en cours
  bool _isCalculatingRoute = false;

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
  // MÉTHODES ITINÉRAIRE
  // ============================================

  /// Calculer l'itinéraire vers une construction
  Future<void> _calculateRouteToConstruction(Construction construction) async {
    // Vérifier la position utilisateur
    if (_userPosition == null) {
      await _getCurrentLocation();
      if (_userPosition == null) {
        _showError('Position GPS requise pour calculer l\'itinéraire');
        return;
      }
    }

    setState(() => _isCalculatingRoute = true);

    try {
      final destination = construction.getCentroid();
      
      final route = await RoutingService.calculateRoute(
        _userPosition!,
        destination,
        travelMode: _travelMode,
      );

      if (route != null) {
        setState(() {
          _currentRoute = route;
          _selectedConstruction = construction;
        });
        
        // Ajuster la vue pour afficher tout l'itinéraire
        _fitRouteOnMap(route);
        
        // Afficher le panneau d'itinéraire
        _showRoutePanel();
      } else {
        _showError('Impossible de calculer l\'itinéraire');
      }
    } catch (e) {
      _showError('Erreur lors du calcul de l\'itinéraire');
      debugPrint('Erreur routing: $e');
    } finally {
      setState(() => _isCalculatingRoute = false);
    }
  }

  /// Recalculer l'itinéraire avec un nouveau mode de transport
  Future<void> _recalculateRoute(TravelMode newMode) async {
    if (_currentRoute == null) return;
    
    setState(() {
      _travelMode = newMode;
      _isCalculatingRoute = true;
    });

    try {
      final route = await RoutingService.calculateRoute(
        _currentRoute!.origin,
        _currentRoute!.destination,
        travelMode: newMode,
      );

      if (route != null) {
        setState(() => _currentRoute = route);
      } else {
        _showError('Impossible de recalculer l\'itinéraire');
      }
    } catch (e) {
      _showError('Erreur lors du recalcul');
    } finally {
      setState(() => _isCalculatingRoute = false);
    }
  }

  /// Ajuster la vue de la carte pour afficher l'itinéraire complet
  void _fitRouteOnMap(RouteInfo route) {
    if (route.polylinePoints.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;

    for (var point in route.polylinePoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  /// Afficher le panneau d'itinéraire
  void _showRoutePanel() {
    if (_currentRoute == null) return;
    
    RouteBottomSheet.show(
      context,
      routeInfo: _currentRoute!,
      onTravelModeChanged: (mode) {
        Navigator.pop(context);
        _recalculateRoute(mode);
      },
      onStartNavigation: () {
        Navigator.pop(context);
        _startExternalNavigation();
      },
      onShare: () {
        _shareRoute();
      },
      onClose: () {
        setState(() {
          _currentRoute = null;
        });
      },
    );
  }

  /// Démarrer la navigation dans une application externe
  Future<void> _startExternalNavigation() async {
    if (_currentRoute == null || _userPosition == null) return;
    
    final destination = _currentRoute!.destination;
    
    // URL pour Google Maps
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${_userPosition!.latitude},${_userPosition!.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&travelmode=${_travelMode == TravelMode.driving ? 'driving' : _travelMode == TravelMode.walking ? 'walking' : 'bicycling'}'
    );
    
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        _showError('Impossible d\'ouvrir l\'application de navigation');
      }
    } catch (e) {
      _showError('Erreur lors du lancement de la navigation');
    }
  }

  /// Partager l'itinéraire
  Future<void> _shareRoute() async {
    if (_currentRoute == null) return;
    
    final destination = _currentRoute!.destination;
    final url = 'https://www.google.com/maps/dir/'
        '${_userPosition?.latitude ?? ''},${_userPosition?.longitude ?? ''}/'
        '${destination.latitude},${destination.longitude}';
    
    // Copier dans le presse-papiers (Share API disponible via url_launcher)
    _showSuccess('Lien copié: ${_currentRoute!.formattedDistance}');
  }

  /// Effacer l'itinéraire actuel
  void _clearRoute() {
    setState(() {
      _currentRoute = null;
    });
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
      onRoute: () => _calculateRouteToConstruction(construction),
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
    
    // Si un itinéraire est actif, n'afficher que le polygone de destination
    List<Construction> constructionsToShow = _filteredConstructions;
    if (_currentRoute != null && _selectedConstruction != null) {
      constructionsToShow = _filteredConstructions
          .where((c) => c.id == _selectedConstruction!.id)
          .toList();
    }
    
    for (var construction in constructionsToShow) {
      try {
        List<LatLng> points = construction.getPolygonPoints();
        if (points.length >= 3) {
          Color color = _getColorForType(construction.type);
          bool isSelected = _selectedConstruction?.id == construction.id;

          polygons.add(
            Polygon(
              points: points,
              color: color.withOpacity(isSelected ? 0.35 : 0.15),
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

  /// Construire les marqueurs pour le MarkerLayer avec clustering
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

    // Marqueurs de l'itinéraire (départ et arrivée)
    if (_currentRoute != null) {
      // Marqueur de départ (position utilisateur - vert)
      markers.add(
        Marker(
          point: _currentRoute!.origin,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.trip_origin,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );

      // Marqueur d'arrivée (destination - rouge)
      markers.add(
        Marker(
          point: _currentRoute!.destination,
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      );
      
      // Ne pas afficher les autres marqueurs quand un itinéraire est actif
      return markers;
    }

    // Clustering des constructions (seulement si pas d'itinéraire actif)
    final clusters = MarkerClusterer.clusterConstructions(
      _filteredConstructions,
      _currentZoom,
      gridSize: 60,
      minZoomForClustering: 16,
    );

    // Créer les marqueurs pour chaque cluster
    for (var cluster in clusters) {
      final isSelected = cluster.constructions.any(
        (c) => c.id == _selectedConstruction?.id,
      );

      markers.add(
        Marker(
          point: cluster.position,
          width: cluster.isCluster ? 80 : (isSelected ? 50 : 40),
          height: cluster.isCluster ? 80 : (isSelected ? 50 : 40),
          child: GestureDetector(
            onTap: () {
              if (cluster.isCluster) {
                // Clic sur un cluster : zoomer pour décomposer
                _mapController.move(
                  cluster.position,
                  math.min(_currentZoom + 2.5, 18),
                );
              } else {
                // Clic sur un marqueur simple : afficher les infos
                _showConstructionInfo(cluster.constructions.first);
              }
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: cluster.isCluster ? 400 : 300),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: MarkerClusterer.buildClusterWidget(cluster, _typeColors),
              ),
            ),
          ),
        ),
      );
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
                
                // Indicateur de calcul d'itinéraire
                if (_isCalculatingRoute)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.blue),
                            const SizedBox(height: 16),
                            Text(
                              'Calcul de l\'itinéraire...',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Panneau d'itinéraire compact (en bas)
                if (_currentRoute != null && !_isCalculatingRoute)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 100,
                    child: _buildCompactRouteInfo(),
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
        // Bouton liste avec badge moderne
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openConstructionList,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        Icons.list_alt_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              if (_constructions.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '${_constructions.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Bouton rafraîchir moderne
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _refreshConstructions,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(10),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
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
        onPositionChanged: (position, hasGesture) {
          // Mettre à jour le zoom pour le clustering
          if (position.zoom != null && position.zoom != _currentZoom) {
            setState(() {
              _currentZoom = position.zoom!;
            });
          }
        },
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
        
        // Polyline de l'itinéraire
        if (_currentRoute != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _currentRoute!.polylinePoints,
                color: Colors.blue,
                strokeWidth: 5.0,
                borderColor: Colors.blue.shade900,
                borderStrokeWidth: 1.0,
              ),
            ],
          ),
        
        // Marqueurs (constructions + GPS + itinéraire)
        MarkerLayer(markers: _buildMarkers()),
      ],
    );
  }

  /// Panneau compact d'information de l'itinéraire
  Widget _buildCompactRouteInfo() {
    if (_currentRoute == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ligne supérieure: distance, durée et bouton fermer
          Row(
            children: [
              // Icône mode de transport
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _currentRoute!.travelMode.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Distance et durée
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _currentRoute!.formattedDuration,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _currentRoute!.formattedDistance,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Arrivée: ${_currentRoute!.estimatedArrival}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bouton fermer
              IconButton(
                onPressed: _clearRoute,
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Ligne inférieure: modes de transport + navigation
          Row(
            children: [
              // Sélecteurs de mode de transport compacts
              ...TravelMode.values.map((mode) {
                final isSelected = _currentRoute!.travelMode == mode;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _recalculateRoute(mode),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        mode.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                );
              }),
              
              const Spacer(),
              
              // Bouton démarrer navigation
              ElevatedButton.icon(
                onPressed: _startExternalNavigation,
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Démarrer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
