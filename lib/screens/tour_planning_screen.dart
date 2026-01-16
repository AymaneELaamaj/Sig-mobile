import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../db/database_helper.dart';
import '../models/construction.dart';
import '../models/tour.dart';
import '../services/routing_service.dart';
import '../utils/geojson_helper.dart';
import 'navigation_screen.dart';

/// Écran de planification de tournée
/// 
/// Permet de :
/// - Sélectionner les constructions à visiter
/// - Optimiser l'itinéraire
/// - Démarrer la navigation
class TourPlanningScreen extends StatefulWidget {
  const TourPlanningScreen({super.key});

  @override
  State<TourPlanningScreen> createState() => _TourPlanningScreenState();
}

class _TourPlanningScreenState extends State<TourPlanningScreen>
    with SingleTickerProviderStateMixin {
  
  // ============================================
  // DONNÉES
  // ============================================
  
  List<Construction> _allConstructions = [];
  List<Construction> _selectedConstructions = [];
  List<TourStop> _optimizedStops = [];
  LatLng? _currentPosition;
  
  // ============================================
  // ÉTATS
  // ============================================
  
  bool _isLoading = true;
  bool _isOptimizing = false;
  bool _isCreatingTour = false;
  String? _tourName;
  String _filterType = 'Tous';
  String _searchQuery = '';

  // ============================================
  // ANIMATION
  // ============================================
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // ============================================
  // CONSTANTES
  // ============================================
  
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
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ============================================
  // CHARGEMENT DES DONNÉES
  // ============================================

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Charger les constructions
      final constructions = await DatabaseHelper.instance.readAllConstructions();
      
      // Obtenir la position actuelle
      await _getCurrentPosition();
      
      setState(() {
        _allConstructions = constructions;
        _isLoading = false;
      });
      
      _animController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur de chargement: $e');
    }
  }

  Future<void> _getCurrentPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _currentPosition = LatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      // Position par défaut (Casablanca)
      _currentPosition = const LatLng(33.5731, -7.5898);
    }
  }

  // ============================================
  // GESTION DE LA SÉLECTION
  // ============================================

  void _toggleSelection(Construction construction) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedConstructions.contains(construction)) {
        _selectedConstructions.remove(construction);
      } else {
        _selectedConstructions.add(construction);
      }
      // Réinitialiser l'optimisation si la sélection change
      _optimizedStops.clear();
    });
  }

  void _selectAll() {
    setState(() {
      _selectedConstructions = List.from(_getFilteredConstructions());
      _optimizedStops.clear();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedConstructions.clear();
      _optimizedStops.clear();
    });
  }

  List<Construction> _getFilteredConstructions() {
    return _allConstructions.where((c) {
      final matchesType = _filterType == 'Tous' || c.type == _filterType;
      final matchesSearch = _searchQuery.isEmpty ||
          c.adresse.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.contact.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesType && matchesSearch;
    }).toList();
  }

  // ============================================
  // OPTIMISATION DE L'ITINÉRAIRE
  // ============================================

  Future<void> _optimizeRoute() async {
    if (_selectedConstructions.isEmpty) {
      _showError('Sélectionnez au moins une construction');
      return;
    }

    if (_currentPosition == null) {
      await _getCurrentPosition();
      if (_currentPosition == null) {
        _showError('Position GPS non disponible');
        return;
      }
    }

    setState(() => _isOptimizing = true);
    HapticFeedback.mediumImpact();

    try {
      // Convertir les constructions en TourStops
      List<TourStop> stops = _selectedConstructions.map((c) {
        final centroid = GeoJsonHelper.geoJsonToPoints(c.geom).isNotEmpty
            ? GeoJsonHelper.calculateCentroid(GeoJsonHelper.geoJsonToPoints(c.geom))
            : const LatLng(33.5731, -7.5898);
        
        return TourStop(
          constructionId: c.id!,
          adresse: c.adresse,
          type: c.type,
          position: centroid,
        );
      }).toList();

      // Optimiser avec OSRM ou algorithme local
      final optimized = await RoutingService.optimizeRouteOSRM(
        _currentPosition!,
        stops,
      );

      setState(() {
        _optimizedStops = optimized ?? stops;
        _isOptimizing = false;
      });

      _showSuccess('Itinéraire optimisé !');
    } catch (e) {
      setState(() => _isOptimizing = false);
      _showError('Erreur d\'optimisation: $e');
    }
  }

  // ============================================
  // CRÉATION ET DÉMARRAGE DE LA TOURNÉE
  // ============================================

  Future<void> _createAndStartTour() async {
    if (_optimizedStops.isEmpty) {
      _showError('Optimisez d\'abord l\'itinéraire');
      return;
    }

    // Demander le nom de la tournée
    final name = await _showNameDialog();
    if (name == null || name.isEmpty) return;

    setState(() => _isCreatingTour = true);

    try {
      // Créer la tournée
      final tour = Tour(
        name: name,
        createdAt: DateTime.now(),
        stops: _optimizedStops,
      );

      // Sauvegarder en base
      final tourId = await DatabaseHelper.instance.createTour(tour);
      await DatabaseHelper.instance.addTourStops(tourId, _optimizedStops);
      
      // Marquer comme démarrée
      await DatabaseHelper.instance.startTour(tourId);

      // Récupérer la tournée complète
      final savedTour = await DatabaseHelper.instance.readTour(tourId);

      if (mounted && savedTour != null) {
        // Naviguer vers l'écran de navigation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => NavigationScreen(tour: savedTour),
          ),
        );
      }
    } catch (e) {
      _showError('Erreur de création: $e');
    } finally {
      setState(() => _isCreatingTour = false);
    }
  }

  Future<String?> _showNameDialog() async {
    final controller = TextEditingController(
      text: 'Tournée du ${DateTime.now().day}/${DateTime.now().month}',
    );

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.route, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Text('Nom de la tournée'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ex: Tournée centre-ville',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Démarrer'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // UI HELPERS
  // ============================================

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
            const Icon(Icons.check_circle, color: Colors.white),
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
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // En-tête avec stats
                _buildHeader(),
                
                // Filtres
                _buildFilters(),
                
                // Liste des constructions
                Expanded(
                  child: _buildConstructionList(),
                ),
                
                // Panneau d'itinéraire optimisé
                if (_optimizedStops.isNotEmpty) _buildOptimizedPanel(),
                
                // Barre d'actions
                _buildActionBar(),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.route, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Planifier une tournée',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Sélectionnez les constructions',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (_selectedConstructions.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearSelection,
            tooltip: 'Tout désélectionner',
          ),
      ],
    );
  }

  Widget _buildHeader() {
    final totalDistance = _optimizedStops.isEmpty
        ? 0.0
        : RoutingService.calculateTotalDistance(_optimizedStops);
    final totalDuration = _optimizedStops.isEmpty
        ? 0.0
        : RoutingService.estimateTotalDuration(_optimizedStops);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade600, Colors.blue.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sélection
          _buildStatCard(
            icon: Icons.check_circle,
            value: '${_selectedConstructions.length}',
            label: 'sélectionnés',
            color: Colors.white,
          ),
          const SizedBox(width: 16),
          
          // Distance
          _buildStatCard(
            icon: Icons.straighten,
            value: RoutingService.formatDistance(totalDistance),
            label: 'distance',
            color: Colors.white,
          ),
          const SizedBox(width: 16),
          
          // Durée
          _buildStatCard(
            icon: Icons.schedule,
            value: RoutingService.formatDuration(totalDuration),
            label: 'estimé',
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color.withOpacity(0.8), size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final types = ['Tous', 'Résidentiel', 'Commercial', 'Industriel', 'Public'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Rechercher une adresse...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          
          // Chips de filtre
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: types.map((type) {
                final isSelected = _filterType == type;
                final color = type == 'Tous'
                    ? Colors.grey
                    : _typeColors[type] ?? Colors.grey;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _filterType = type),
                    backgroundColor: Colors.white,
                    selectedColor: color.withOpacity(0.2),
                    checkmarkColor: color,
                    labelStyle: TextStyle(
                      color: isSelected ? color : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? color : Colors.grey[300]!,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          
          // Bouton tout sélectionner
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _selectAll,
                icon: const Icon(Icons.select_all, size: 18),
                label: Text(
                  'Tout sélectionner (${_getFilteredConstructions().length})',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConstructionList() {
    final filtered = _getFilteredConstructions();
    
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucune construction trouvée',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final construction = filtered[index];
          final isSelected = _selectedConstructions.contains(construction);
          final color = _typeColors[construction.type] ?? Colors.grey;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? color.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: isSelected ? 10 : 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _toggleSelection(construction),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Checkbox animée
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected ? color : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? color : Colors.grey[400]!,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      
                      // Contenu
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              construction.adresse,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              construction.contact,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Badge type
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          construction.type,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptimizedPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 10),
              const Text(
                'Itinéraire optimisé',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Spacer(),
              Text(
                '${_optimizedStops.length} arrêts',
                style: const TextStyle(color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Liste des stops optimisés
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _optimizedStops.length,
              itemBuilder: (context, index) {
                final stop = _optimizedStops[index];
                final color = _typeColors[stop.type] ?? Colors.grey;
                
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: color,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        stop.adresse.length > 15
                            ? '${stop.adresse.substring(0, 15)}...'
                            : stop.adresse,
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Bouton optimiser
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectedConstructions.isEmpty || _isOptimizing
                    ? null
                    : _optimizeRoute,
                icon: _isOptimizing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(_isOptimizing ? 'Optimisation...' : 'Optimiser'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Bouton démarrer
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _optimizedStops.isEmpty || _isCreatingTour
                    ? null
                    : _createAndStartTour,
                icon: _isCreatingTour
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.navigation),
                label: Text(_isCreatingTour ? 'Création...' : 'Démarrer la tournée'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
