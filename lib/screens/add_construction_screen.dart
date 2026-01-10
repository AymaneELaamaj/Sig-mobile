import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../db/database_helper.dart';
import '../models/construction.dart';
import '../utils/geojson_helper.dart';

/// Écran pour ajouter une nouvelle construction
/// 
/// Design Material 3 professionnel avec :
/// - Interface de dessin intuitive
/// - Stepper visuel pour guider l'utilisateur
/// - Formulaire moderne avec validation
/// - Animations et feedbacks visuels
class AddConstructionScreen extends StatefulWidget {
  const AddConstructionScreen({super.key});

  @override
  State<AddConstructionScreen> createState() => _AddConstructionScreenState();
}

class _AddConstructionScreenState extends State<AddConstructionScreen>
    with TickerProviderStateMixin {
  
  // ============================================
  // CONTRÔLEURS
  // ============================================
  
  final _formKey = GlobalKey<FormState>();
  final _adresseController = TextEditingController();
  final _contactController = TextEditingController();
  final MapController _mapController = MapController();
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ============================================
  // DONNÉES
  // ============================================
  
  String _selectedType = 'Résidentiel';
  List<LatLng> _polygonPoints = [];
  String? _geoJsonResult;
  LatLng _currentPosition = const LatLng(33.5731, -7.5898);

  // ============================================
  // ÉTATS
  // ============================================
  
  int _currentStep = 0; // 0: Dessin, 1: Formulaire
  bool _isLocating = false;
  bool _isSaving = false;
  String? _polygonError;

  // ============================================
  // CONSTANTES
  // ============================================
  
  static const Map<String, _TypeInfo> _typeInfos = {
    'Résidentiel': _TypeInfo(Colors.red, Icons.home, 'Habitation'),
    'Commercial': _TypeInfo(Colors.blue, Icons.business, 'Commerce'),
    'Industriel': _TypeInfo(Colors.orange, Icons.factory, 'Industrie'),
    'Public': _TypeInfo(Colors.green, Icons.account_balance, 'Service public'),
  };

  // ============================================
  // CYCLE DE VIE
  // ============================================

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _adresseController.dispose();
    _contactController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================
  // MÉTHODES GPS
  // ============================================

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showGpsDialog();
        setState(() => _isLocating = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLocating = false;
      });

      _mapController.move(_currentPosition, 17);
    } catch (e) {
      setState(() => _isLocating = false);
    }
  }

  void _showGpsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.gps_off, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            const Text('GPS désactivé'),
          ],
        ),
        content: const Text(
          'Activez le GPS pour une meilleure précision de localisation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // MÉTHODES DESSIN
  // ============================================

  void _addPoint(LatLng point) {
    HapticFeedback.lightImpact();
    setState(() {
      _polygonPoints.add(point);
      _polygonError = null;
    });
  }

  void _removeLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _polygonPoints.removeLast();
        _polygonError = null;
      });
    }
  }

  void _resetDrawing() {
    setState(() {
      _polygonPoints.clear();
      _geoJsonResult = null;
      _polygonError = null;
      _currentStep = 0;
    });
  }

  void _validatePolygon() {
    if (_polygonPoints.length < 3) {
      setState(() => _polygonError = 'Minimum 3 points requis');
      return;
    }

    if (GeoJsonHelper.isSelfIntersecting(_polygonPoints)) {
      setState(() => _polygonError = 'Le polygone ne doit pas se croiser');
      return;
    }

    try {
      String geoJson = GeoJsonHelper.pointsToGeoJson(_polygonPoints);
      setState(() {
        _geoJsonResult = geoJson;
        _polygonError = null;
        _currentStep = 1;
      });
      _showSuccess('Polygone validé !');
    } catch (e) {
      setState(() => _polygonError = 'Erreur de validation');
    }
  }

  // ============================================
  // MÉTHODES UI
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

  Color get _currentColor => _typeInfos[_selectedType]?.color ?? Colors.blue;

  Future<void> _saveConstruction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_geoJsonResult == null) {
      _showError('Veuillez d\'abord dessiner le polygone');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newConstruction = Construction(
        adresse: _adresseController.text,
        contact: _contactController.text,
        type: _selectedType,
        geom: _geoJsonResult!,
      );

      await DatabaseHelper.instance.create(newConstruction);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Erreur lors de la sauvegarde');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Stepper visuel
          _buildStepper(),
          
          // Contenu principal
          Expanded(
            child: _currentStep == 0 ? _buildDrawingStep() : _buildFormStep(),
          ),
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
              color: _currentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _typeInfos[_selectedType]?.icon ?? Icons.add_location,
              color: _currentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Nouvelle Construction',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        if (_currentStep == 1)
          TextButton.icon(
            onPressed: _resetDrawing,
            icon: const Icon(Icons.edit_location_alt, size: 18),
            label: const Text('Modifier'),
          ),
      ],
    );
  }

  /// Stepper visuel en haut
  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Étape 1: Dessin
          _buildStepIndicator(
            step: 0,
            icon: Icons.draw,
            label: 'Dessiner',
            isActive: _currentStep == 0,
            isCompleted: _currentStep > 0,
          ),
          
          // Ligne de connexion
          Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _currentStep > 0 ? Colors.green : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Étape 2: Formulaire
          _buildStepIndicator(
            step: 1,
            icon: Icons.description,
            label: 'Informations',
            isActive: _currentStep == 1,
            isCompleted: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator({
    required int step,
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    Color bgColor = isCompleted
        ? Colors.green
        : isActive
            ? _currentColor
            : Colors.grey[300]!;
    Color textColor = isActive || isCompleted ? bgColor : Colors.grey;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive || isCompleted ? bgColor : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: bgColor, width: 2),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: bgColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: isActive || isCompleted ? Colors.white : Colors.grey,
            size: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
      ],
    );
  }

  /// Étape 1: Dessin du polygone
  Widget _buildDrawingStep() {
    return Stack(
      children: [
        // Carte
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition,
            initialZoom: 17.0,
            onTap: (tapPosition, point) => _addPoint(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.sig_mobile',
            ),
            
            // Polygone
            if (_polygonPoints.length >= 3)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _polygonPoints,
                    color: _currentColor.withOpacity(0.25),
                    borderColor: _currentColor,
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
            
            // Lignes
            if (_polygonPoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _polygonPoints,
                    strokeWidth: 3,
                    color: _currentColor,
                  ),
                  if (_polygonPoints.length >= 3)
                    Polyline(
                      points: [_polygonPoints.last, _polygonPoints.first],
                      strokeWidth: 2,
                      color: _currentColor.withOpacity(0.5),
                      isDotted: true,
                    ),
                ],
              ),
            
            // Marqueurs des points
            MarkerLayer(
              markers: _polygonPoints.asMap().entries.map((entry) {
                return Marker(
                  point: entry.value,
                  width: 36,
                  height: 36,
                  child: _buildPointMarker(entry.key + 1),
                );
              }).toList(),
            ),
            
            // Position actuelle
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentPosition,
                  width: 24,
                  height: 24,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        
        // Overlay de chargement GPS
        if (_isLocating) _buildLoadingOverlay(),
        
        // Panneau d'instructions en haut
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: _buildInstructionPanel(),
        ),
        
        // Contrôles de carte
        Positioned(
          right: 16,
          bottom: 100,
          child: _buildMapControls(),
        ),
        
        // Barre d'actions en bas
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildDrawingActions(),
        ),
      ],
    );
  }

  Widget _buildPointMarker(int number) {
    return Container(
      decoration: BoxDecoration(
        color: _currentColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Recherche GPS...',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.touch_app, color: _currentColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Dessinez le polygone',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              // Compteur de points
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _polygonPoints.length >= 3
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _polygonPoints.length >= 3
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color: _polygonPoints.length >= 3
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_polygonPoints.length}/3',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _polygonPoints.length >= 3
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          Text(
            'Touchez la carte pour placer les sommets du polygone.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          
          // Erreur
          if (_polygonError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _polygonError!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapControls() {
    return Container(
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
          // GPS
          _buildControlButton(
            icon: Icons.my_location,
            color: Colors.blue,
            onTap: _getCurrentLocation,
          ),
          const Divider(height: 1),
          // Zoom +
          _buildControlButton(
            icon: Icons.add,
            onTap: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom + 1,
              );
            },
          ),
          const Divider(height: 1),
          // Zoom -
          _buildControlButton(
            icon: Icons.remove,
            onTap: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom - 1,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    Color color = Colors.black87,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildDrawingActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Bouton annuler
            if (_polygonPoints.isNotEmpty)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _removeLastPoint,
                  icon: const Icon(Icons.undo),
                  label: const Text('Annuler'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            
            if (_polygonPoints.isNotEmpty) const SizedBox(width: 12),
            
            // Bouton réinitialiser
            if (_polygonPoints.length > 1)
              IconButton(
                onPressed: _resetDrawing,
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                tooltip: 'Tout effacer',
              ),
            
            if (_polygonPoints.length > 1) const SizedBox(width: 12),
            
            // Bouton valider
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _polygonPoints.length >= 3 ? _validatePolygon : null,
                icon: const Icon(Icons.check),
                label: const Text('Valider le polygone'),
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

  /// Étape 2: Formulaire
  Widget _buildFormStep() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Aperçu du polygone
          _buildPolygonPreview(),
          
          // Formulaire
          _buildForm(),
        ],
      ),
    );
  }

  Widget _buildPolygonPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Mini carte
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 150,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _polygonPoints.isNotEmpty
                      ? GeoJsonHelper.calculateCentroid(_polygonPoints)
                      : _currentPosition,
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  if (_polygonPoints.length >= 3)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: _polygonPoints,
                          color: _currentColor.withOpacity(0.3),
                          borderColor: _currentColor,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          // Infos du polygone
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Polygone validé',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_polygonPoints.length} sommets • ${GeoJsonHelper.calculateArea(_polygonPoints).toStringAsFixed(1)} m²',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _resetDrawing,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Modifier'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _currentColor,
                    side: BorderSide(color: _currentColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _currentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.description, color: _currentColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Informations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Type de construction
            const Text(
              'Type de construction',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 10),
            _buildTypeSelector(),
            const SizedBox(height: 20),
            
            // Adresse
            const Text(
              'Adresse',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _adresseController,
              decoration: InputDecoration(
                hintText: 'Ex: 123 Rue Mohammed V, Casablanca',
                prefixIcon: const Icon(Icons.location_on_outlined),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _currentColor, width: 2),
                ),
              ),
              validator: (value) =>
                  value!.isEmpty ? 'L\'adresse est requise' : null,
            ),
            const SizedBox(height: 20),
            
            // Contact
            const Text(
              'Contact / Propriétaire',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _contactController,
              decoration: InputDecoration(
                hintText: 'Ex: Ahmed Benali - 0661234567',
                prefixIcon: const Icon(Icons.person_outline),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _currentColor, width: 2),
                ),
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Le contact est requis' : null,
            ),
            const SizedBox(height: 30),
            
            // Bouton enregistrer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveConstruction,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _typeInfos.entries.map((entry) {
          final isSelected = _selectedType == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedType = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? entry.value.color : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? entry.value.color : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: entry.value.color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      entry.value.icon,
                      color: isSelected ? Colors.white : entry.value.color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.key,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[800],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TypeInfo {
  final Color color;
  final IconData icon;
  final String description;

  const _TypeInfo(this.color, this.icon, this.description);
}
