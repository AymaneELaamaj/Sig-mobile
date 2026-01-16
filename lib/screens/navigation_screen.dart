import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/database_helper.dart';
import '../models/tour.dart';
import '../services/routing_service.dart';

/// Écran de navigation GPS
/// 
/// Affiche :
/// - Carte avec itinéraire
/// - Instructions turn-by-turn
/// - Liste des stops avec statut
/// - Actions (marquer visité, passer, etc.)
class NavigationScreen extends StatefulWidget {
  final Tour tour;

  const NavigationScreen({super.key, required this.tour});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {
  
  // ============================================
  // CONTRÔLEURS
  // ============================================
  
  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ============================================
  // DONNÉES
  // ============================================
  
  late Tour _tour;
  LatLng? _currentPosition;
  RouteSegment? _currentRoute;
  List<LatLng> _routePolyline = [];
  
  // ============================================
  // ÉTATS
  // ============================================
  
  bool _isLoadingRoute = false;
  bool _isFollowing = true;
  int _currentStopIndex = 0;

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
    _tour = widget.tour;
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _initNavigation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================
  // INITIALISATION
  // ============================================

  Future<void> _initNavigation() async {
    await _getCurrentPosition();
    await _loadRouteToNextStop();
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
        
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });

        if (_isFollowing && _currentPosition != null) {
          _mapController.move(_currentPosition!, 16);
        }
      }
    } catch (e) {
      // Position par défaut
      _currentPosition = const LatLng(33.5731, -7.5898);
    }
  }

  Future<void> _loadRouteToNextStop() async {
    final nextStop = _getNextPendingStop();
    if (nextStop == null || _currentPosition == null) return;

    setState(() => _isLoadingRoute = true);

    try {
      final route = await RoutingService.getRoute(
        _currentPosition!,
        nextStop.position,
      );

      if (route != null) {
        setState(() {
          _currentRoute = route;
          _routePolyline = route.polylinePoints;
          _isLoadingRoute = false;
        });
      } else {
        setState(() => _isLoadingRoute = false);
      }
    } catch (e) {
      setState(() => _isLoadingRoute = false);
    }
  }

  TourStop? _getNextPendingStop() {
    final pending = _tour.stops
        .where((s) => s.status == VisitStatus.pending)
        .toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return pending.first;
  }

  // ============================================
  // ACTIONS SUR LES STOPS
  // ============================================

  Future<void> _markAsVisited(TourStop stop) async {
    HapticFeedback.mediumImpact();
    
    await DatabaseHelper.instance.updateTourStopStatus(
      _tour.id!,
      stop.constructionId,
      VisitStatus.visited,
    );

    setState(() {
      final index = _tour.stops.indexWhere(
        (s) => s.constructionId == stop.constructionId,
      );
      if (index != -1) {
        _tour.stops[index] = _tour.stops[index].copyWith(
          status: VisitStatus.visited,
          visitedAt: DateTime.now(),
        );
      }
    });

    _showSuccess('${stop.adresse} marqué comme visité !');
    
    // Charger l'itinéraire vers le prochain
    await _loadRouteToNextStop();
    
    // Vérifier si la tournée est terminée
    if (_tour.isCompleted) {
      await _completeTour();
    }
  }

  Future<void> _markAsToReview(TourStop stop, {String? notes}) async {
    HapticFeedback.lightImpact();
    
    await DatabaseHelper.instance.updateTourStopStatus(
      _tour.id!,
      stop.constructionId,
      VisitStatus.toReview,
      notes: notes,
    );

    setState(() {
      final index = _tour.stops.indexWhere(
        (s) => s.constructionId == stop.constructionId,
      );
      if (index != -1) {
        _tour.stops[index] = _tour.stops[index].copyWith(
          status: VisitStatus.toReview,
          notes: notes,
        );
      }
    });

    _showInfo('${stop.adresse} marqué à revoir');
    await _loadRouteToNextStop();
  }

  Future<void> _skipStop(TourStop stop) async {
    HapticFeedback.lightImpact();
    
    await DatabaseHelper.instance.updateTourStopStatus(
      _tour.id!,
      stop.constructionId,
      VisitStatus.skipped,
    );

    setState(() {
      final index = _tour.stops.indexWhere(
        (s) => s.constructionId == stop.constructionId,
      );
      if (index != -1) {
        _tour.stops[index] = _tour.stops[index].copyWith(
          status: VisitStatus.skipped,
        );
      }
    });

    await _loadRouteToNextStop();
  }

  Future<void> _completeTour() async {
    await DatabaseHelper.instance.completeTour(_tour.id!);
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration,
                  color: Colors.green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tournée terminée !',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_tour.visitedCount} constructions visitées\n'
                '${_tour.toReviewCount} à revoir',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Terminer'),
            ),
          ],
        ),
      );
    }
  }

  // ============================================
  // NAVIGATION EXTERNE
  // ============================================

  Future<void> _openInMaps(TourStop stop) async {
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&destination=${stop.position.latitude},${stop.position.longitude}'
        '&travelmode=driving';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _showError('Impossible d\'ouvrir Maps');
    }
  }

  // ============================================
  // UI HELPERS
  // ============================================

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

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
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

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Carte
          _buildMap(),
          
          // En-tête avec infos
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(),
          ),
          
          // Panneau de navigation en bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildNavigationPanel(),
          ),
          
          // Bouton de recentrage
          Positioned(
            right: 16,
            bottom: 280,
            child: _buildMapControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition ?? const LatLng(33.5731, -7.5898),
        initialZoom: 15,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) {
            setState(() => _isFollowing = false);
          }
        },
      ),
      children: [
        // Tuiles de carte
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.sig_mobile',
        ),
        
        // Itinéraire
        if (_routePolyline.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePolyline,
                strokeWidth: 5,
                color: Colors.blue,
              ),
            ],
          ),
        
        // Marqueurs des stops
        MarkerLayer(
          markers: _tour.stops.map((stop) {
            final color = _typeColors[stop.type] ?? Colors.grey;
            final isNext = _getNextPendingStop()?.constructionId == stop.constructionId;
            
            return Marker(
              point: stop.position,
              width: isNext ? 50 : 40,
              height: isNext ? 50 : 40,
              child: _buildStopMarker(stop, color, isNext),
            );
          }).toList(),
        ),
        
        // Position actuelle
        if (_currentPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _currentPosition!,
                width: 40,
                height: 40,
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 3),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.navigation,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStopMarker(TourStop stop, Color color, bool isNext) {
    IconData icon;
    Color bgColor;
    
    switch (stop.status) {
      case VisitStatus.visited:
        icon = Icons.check;
        bgColor = Colors.green;
        break;
      case VisitStatus.toReview:
        icon = Icons.refresh;
        bgColor = Colors.orange;
        break;
      case VisitStatus.skipped:
        icon = Icons.skip_next;
        bgColor = Colors.grey;
        break;
      default:
        icon = Icons.location_on;
        bgColor = color;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: isNext ? 4 : 3),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: bgColor.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: isNext ? 24 : 18,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Bouton retour
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _showExitDialog(),
                ),
              ),
              const SizedBox(width: 16),
              
              // Titre et progression
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tour.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Barre de progression
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: _tour.progress / 100,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_tour.visitedCount}/${_tour.stops.length} visités',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationPanel() {
    final nextStop = _getNextPendingStop();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            if (nextStop != null) ...[
              // Info du prochain stop
              _buildNextStopInfo(nextStop),
              
              const Divider(height: 24),
              
              // Actions
              _buildStopActions(nextStop),
            ] else ...[
              // Tournée terminée
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.celebration,
                      color: Colors.green,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tous les arrêts ont été traités !',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 8),
            
            // Liste des stops
            _buildStopsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildNextStopInfo(TourStop stop) {
    final color = _typeColors[stop.type] ?? Colors.grey;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Icône
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.location_on, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prochain arrêt',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stop.adresse,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        stop.type,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_currentRoute != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _currentRoute!.distanceFormatted,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _currentRoute!.durationFormatted,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Bouton navigation externe
          IconButton(
            onPressed: () => _openInMaps(stop),
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Ouvrir dans Maps',
          ),
        ],
      ),
    );
  }

  Widget _buildStopActions(TourStop stop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Passer
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _skipStop(stop),
              icon: const Icon(Icons.skip_next, size: 18),
              label: const Text('Passer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[400]!),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // À revoir
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showReviewDialog(stop),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('À revoir'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Visité
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _markAsVisited(stop),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Visité'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopsList() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _tour.stops.length,
        itemBuilder: (context, index) {
          final stop = _tour.stops[index];
          final color = _typeColors[stop.type] ?? Colors.grey;
          final isNext = _getNextPendingStop()?.constructionId == stop.constructionId;
          
          Color statusColor;
          IconData statusIcon;
          
          switch (stop.status) {
            case VisitStatus.visited:
              statusColor = Colors.green;
              statusIcon = Icons.check_circle;
              break;
            case VisitStatus.toReview:
              statusColor = Colors.orange;
              statusIcon = Icons.refresh;
              break;
            case VisitStatus.skipped:
              statusColor = Colors.grey;
              statusIcon = Icons.skip_next;
              break;
            default:
              statusColor = isNext ? color : Colors.grey[400]!;
              statusIcon = Icons.circle_outlined;
          }

          return GestureDetector(
            onTap: () => _mapController.move(stop.position, 17),
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isNext ? color : statusColor,
                            width: isNext ? 3 : 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Icon(
                          statusIcon,
                          size: 16,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stop.adresse.length > 8
                        ? '${stop.adresse.substring(0, 8)}...'
                        : stop.adresse,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapControls() {
    return Column(
      children: [
        // Recalculer itinéraire
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              IconButton(
                onPressed: () async {
                  await _getCurrentPosition();
                  await _loadRouteToNextStop();
                },
                icon: _isLoadingRoute
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'Recalculer',
              ),
              const Divider(height: 1),
              IconButton(
                onPressed: () {
                  if (_currentPosition != null) {
                    setState(() => _isFollowing = true);
                    _mapController.move(_currentPosition!, 16);
                  }
                },
                icon: Icon(
                  Icons.my_location,
                  color: _isFollowing ? Colors.blue : Colors.grey,
                ),
                tooltip: 'Ma position',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showReviewDialog(TourStop stop) async {
    final notesController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Marquer à revoir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stop.adresse,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ajouter une note (optionnel)',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _markAsToReview(stop, notes: notesController.text);
    }
  }

  Future<void> _showExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quitter la navigation ?'),
        content: const Text(
          'Votre progression sera sauvegardée. '
          'Vous pourrez reprendre la tournée plus tard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuer'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context);
    }
  }
}
