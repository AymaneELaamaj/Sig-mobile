import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Widget indicateur de position GPS de l'utilisateur
/// 
/// Affiche un marqueur animé avec :
/// - Un cercle central représentant la position exacte
/// - Un cercle de précision pulsant autour
/// - Une flèche de direction (si disponible)
/// 
/// Utilise des animations fluides pour un rendu professionnel
class GPSIndicatorWidget extends StatefulWidget {
  /// Position actuelle de l'utilisateur
  final LatLng position;
  
  /// Précision du GPS en mètres (rayon du cercle de précision)
  final double accuracy;
  
  /// Direction de l'utilisateur en degrés (0-360), null si non disponible
  final double? heading;
  
  /// Couleur principale du marqueur
  final Color color;

  const GPSIndicatorWidget({
    super.key,
    required this.position,
    this.accuracy = 20.0,
    this.heading,
    this.color = Colors.blue,
  });

  @override
  State<GPSIndicatorWidget> createState() => _GPSIndicatorWidgetState();
}

class _GPSIndicatorWidgetState extends State<GPSIndicatorWidget>
    with TickerProviderStateMixin {
  /// Contrôleur pour l'animation de pulsation
  late AnimationController _pulseController;
  
  /// Animation de pulsation (scale)
  late Animation<double> _pulseAnimation;
  
  /// Animation d'opacité
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    // Configuration de l'animation de pulsation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    // Animation de scale pour le cercle de précision
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Animation d'opacité pour l'effet de fade
    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Cercle de précision pulsant (le plus grand)
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(_opacityAnimation.value * 0.3),
                  border: Border.all(
                    color: widget.color.withOpacity(_opacityAnimation.value),
                    width: 2,
                  ),
                ),
              ),
            );
          },
        ),
        
        // Cercle de fond (précision statique)
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.2),
          ),
        ),
        
        // Marqueur central avec flèche de direction
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.heading != null
              ? Transform.rotate(
                  angle: widget.heading! * (3.14159265359 / 180),
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.white,
                    size: 14,
                  ),
                )
              : const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 14,
                ),
        ),
      ],
    );
  }
}

/// Créer un marqueur GPS pour flutter_map
/// 
/// Usage:
/// ```dart
/// MarkerLayer(
///   markers: [
///     createGPSMarker(
///       position: userPosition,
///       accuracy: 15.0,
///     ),
///   ],
/// )
/// ```
Marker createGPSMarker({
  required LatLng position,
  double accuracy = 20.0,
  double? heading,
  Color color = Colors.blue,
}) {
  return Marker(
    point: position,
    width: 80,
    height: 80,
    child: GPSIndicatorWidget(
      position: position,
      accuracy: accuracy,
      heading: heading,
      color: color,
    ),
  );
}

/// Widget FAB amélioré avec menu d'options
/// 
/// Affiche un FloatingActionButton.extended qui ouvre
/// un BottomSheet avec plusieurs options :
/// - Ajouter une construction par polygone
/// - Ajouter un point GPS simple
/// - Autres options personnalisables
class EnhancedFAB extends StatelessWidget {
  /// Callback pour ajouter une construction avec polygone
  final VoidCallback onAddPolygon;
  
  /// Callback pour ajouter un point GPS simple
  final VoidCallback? onAddPoint;
  
  /// Callback pour importer des données
  final VoidCallback? onImport;

  const EnhancedFAB({
    super.key,
    required this.onAddPolygon,
    this.onAddPoint,
    this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showOptionsSheet(context),
      icon: const Icon(Icons.add_location_alt),
      label: const Text('Nouvelle'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      elevation: 6,
      highlightElevation: 12,
    );
  }

  /// Afficher le BottomSheet avec les options
  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Titre
            const Row(
              children: [
                Icon(Icons.add_location_alt, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text(
                  'Ajouter une construction',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Options
            _OptionTile(
              icon: Icons.pentagon,
              title: 'Dessiner un polygone',
              subtitle: 'Tracer les limites de la construction sur la carte',
              color: Colors.green,
              onTap: () {
                Navigator.pop(ctx);
                onAddPolygon();
              },
            ),
            
            if (onAddPoint != null) ...[
              const SizedBox(height: 12),
              _OptionTile(
                icon: Icons.location_on,
                title: 'Point GPS actuel',
                subtitle: 'Utiliser votre position GPS comme emplacement',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(ctx);
                  onAddPoint!();
                },
              ),
            ],
            
            if (onImport != null) ...[
              const SizedBox(height: 12),
              _OptionTile(
                icon: Icons.file_upload_outlined,
                title: 'Importer des données',
                subtitle: 'Charger des constructions depuis un fichier GeoJSON',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(ctx);
                  onImport!();
                },
              ),
            ],
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Tuile d'option dans le menu FAB
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              // Icône
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              
              // Texte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Flèche
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
