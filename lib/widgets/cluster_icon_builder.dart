import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import '../models/construction.dart';

/// Builder personnalisé pour les icônes de cluster
/// 
/// Crée des cercles colorés avec le nombre d'éléments
/// La taille et la couleur varient selon le nombre de constructions regroupées
class ClusterIconBuilder {
  /// Couleurs par type de construction (pour les stats)
  final Map<String, Color> typeColors;

  ClusterIconBuilder({required this.typeColors});

  /// Construire l'icône de cluster personnalisée
  Widget build(BuildContext context, List<Marker> markers) {
    final count = markers.length;
    
    // Déterminer la taille et la couleur selon le nombre
    final ClusterStyle style = _getClusterStyle(count);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: style.size,
      height: style.size,
      decoration: BoxDecoration(
        color: style.color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: style.fontSize,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
            if (count >= 10)
              Text(
                'zones',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: style.fontSize * 0.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Obtenir le style du cluster selon le nombre d'éléments
  ClusterStyle _getClusterStyle(int count) {
    if (count >= 100) {
      return ClusterStyle(
        size: 70.0,
        fontSize: 20.0,
        color: const Color(0xFFEF4444), // Rouge
      );
    } else if (count >= 50) {
      return ClusterStyle(
        size: 65.0,
        fontSize: 18.0,
        color: const Color(0xFFF59E0B), // Orange
      );
    } else if (count >= 20) {
      return ClusterStyle(
        size: 60.0,
        fontSize: 16.0,
        color: const Color(0xFF10B981), // Vert
      );
    } else if (count >= 10) {
      return ClusterStyle(
        size: 55.0,
        fontSize: 15.0,
        color: const Color(0xFF3B82F6), // Bleu
      );
    } else {
      return ClusterStyle(
        size: 50.0,
        fontSize: 14.0,
        color: const Color(0xFF6366F1), // Indigo
      );
    }
  }

  /// Créer un widget de tooltip pour afficher les infos du cluster au survol
  Widget buildTooltip(BuildContext context, List<Marker> markers) {
    final typeCounts = _getTypeCountsInCluster(markers);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${markers.length} constructions',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...typeCounts.entries.map((entry) {
            final color = typeColors[entry.key] ?? Colors.grey;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${entry.key}: ${entry.value}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Compter les types de constructions dans un cluster
  Map<String, int> _getTypeCountsInCluster(List<Marker> markers) {
    final Map<String, int> counts = {};
    
    // Note: Les markers contiennent les constructions dans leur key
    // Si vous stockez l'objet Construction, vous pourriez le récupérer
    // Pour l'instant, on retourne un comptage simple
    
    return counts;
  }
}

/// Style d'un cluster
class ClusterStyle {
  final double size;
  final double fontSize;
  final Color color;

  ClusterStyle({
    required this.size,
    required this.fontSize,
    required this.color,
  });
}

/// Widget personnalisé pour l'icône de cluster avec animation
class AnimatedClusterIcon extends StatefulWidget {
  final int count;
  final ClusterStyle style;
  final VoidCallback? onTap;

  const AnimatedClusterIcon({
    super.key,
    required this.count,
    required this.style,
    this.onTap,
  });

  @override
  State<AnimatedClusterIcon> createState() => _AnimatedClusterIconState();
}

class _AnimatedClusterIconState extends State<AnimatedClusterIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: widget.style.size,
            height: widget.style.size,
            decoration: BoxDecoration(
              color: widget.style.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isHovered ? 0.4 : 0.3),
                  blurRadius: _isHovered ? 12 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.count}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.style.fontSize,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  if (widget.count >= 10)
                    Text(
                      'zones',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: widget.style.fontSize * 0.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
