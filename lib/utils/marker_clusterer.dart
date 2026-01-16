import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../models/construction.dart';

/// Classe pour gérer le clustering manuel des marqueurs
class MarkerClusterer {
  /// Calculer les clusters de constructions selon le niveau de zoom
  static List<ClusterMarker> clusterConstructions(
    List<Construction> constructions,
    double currentZoom, {
    int gridSize = 60,
    int minZoomForClustering = 16,
  }) {
    // Si le zoom est trop élevé, ne pas clustériser
    if (currentZoom >= minZoomForClustering) {
      return constructions
          .map((c) => ClusterMarker(
                position: c.getCentroid(),
                constructions: [c],
                isCluster: false,
              ))
          .toList();
    }

    // Grille de clustering
    final Map<String, List<Construction>> grid = {};

    for (var construction in constructions) {
      final pos = construction.getCentroid();
      
      // Calculer la cellule de grille pour cette position
      final cellKey = _getCellKey(pos.latitude, pos.longitude, gridSize, currentZoom);
      
      if (!grid.containsKey(cellKey)) {
        grid[cellKey] = [];
      }
      grid[cellKey]!.add(construction);
    }

    // Créer les clusters
    final List<ClusterMarker> clusters = [];
    
    for (var entry in grid.entries) {
      final constructionsInCell = entry.value;
      
      if (constructionsInCell.isEmpty) continue;

      // Calculer le centre du cluster
      double avgLat = 0;
      double avgLng = 0;
      
      for (var construction in constructionsInCell) {
        final pos = construction.getCentroid();
        avgLat += pos.latitude;
        avgLng += pos.longitude;
      }
      
      avgLat /= constructionsInCell.length;
      avgLng /= constructionsInCell.length;

      clusters.add(ClusterMarker(
        position: LatLng(avgLat, avgLng),
        constructions: constructionsInCell,
        isCluster: constructionsInCell.length > 1,
      ));
    }

    return clusters;
  }

  /// Obtenir la clé de cellule de grille pour une position
  static String _getCellKey(double lat, double lng, int gridSize, double zoom) {
    // Ajuster la taille de la grille selon le zoom
    final scale = math.pow(2, zoom).toDouble();
    final adjustedGrid = gridSize / scale;
    
    final latCell = (lat / adjustedGrid).floor();
    final lngCell = (lng / adjustedGrid).floor();
    
    return '$latCell:$lngCell';
  }

  /// Construire le widget pour un cluster
  static Widget buildClusterWidget(ClusterMarker cluster, Map<String, Color> typeColors) {
    final count = cluster.constructions.length;

    if (!cluster.isCluster) {
      // Marqueur simple pour une seule construction - Design amélioré
      final construction = cluster.constructions.first;
      final color = typeColors[construction.type] ?? Colors.grey;
      
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              color,
              color.withOpacity(0.85),
            ],
            stops: const [0.5, 1.0],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 5),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          _getIconForType(construction.type),
          color: Colors.white,
          size: 22,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      );
    }

    // Cluster de plusieurs constructions - Design professionnel
    final ClusterStyle style = _getClusterStyle(count);
    final typeCounts = _getTypeCounts(cluster.constructions);
    
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Effet de halo extérieur animé
        Container(
          width: style.size + 15,
          height: style.size + 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                style.color.withOpacity(0.3),
                style.color.withOpacity(0.1),
                style.color.withOpacity(0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        
        // Cercle extérieur avec effet de profondeur 3D
        Container(
          width: style.size,
          height: style.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [
                style.color.withOpacity(1),
                style.color.withOpacity(0.9),
                style.color.withOpacity(0.7),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: style.color.withOpacity(0.6),
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: 3,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
        ),
        
        // Cercle intérieur blanc pour contraste
        Container(
          width: style.size - 8,
          height: style.size - 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        
        // Contenu du cluster
        Container(
          width: style.size,
          height: style.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Nombre d'éléments avec ombre prononcée
              Text(
                '$count',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: style.fontSize,
                  letterSpacing: 0.8,
                  height: 1.0,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              
              // Texte descriptif
              if (count >= 10)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count >= 100 ? 'zones' : 'sites',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: style.fontSize * 0.45,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Badge avec icône en haut à droite
        if (count >= 20)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.shade100,
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: style.color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.layers,
                size: 12,
                color: style.color,
              ),
            ),
          ),
        
        // Indicateurs de types en bas (cercles colorés)
        if (typeCounts.length > 1)
          Positioned(
            bottom: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: style.color.withOpacity(0.3), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: typeCounts.entries.take(4).map((entry) {
                  final color = typeColors[entry.key] ?? Colors.grey;
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withOpacity(0.8)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  /// Obtenir le style selon le nombre d'éléments
  static ClusterStyle _getClusterStyle(int count) {
    if (count >= 100) {
      return ClusterStyle(
        size: 75.0,
        fontSize: 22.0,
        color: const Color(0xFFDC2626), // Rouge vif
      );
    } else if (count >= 50) {
      return ClusterStyle(
        size: 70.0,
        fontSize: 19.0,
        color: const Color(0xFFEA580C), // Orange vif
      );
    } else if (count >= 20) {
      return ClusterStyle(
        size: 65.0,
        fontSize: 17.0,
        color: const Color(0xFF059669), // Vert émeraude
      );
    } else if (count >= 10) {
      return ClusterStyle(
        size: 60.0,
        fontSize: 16.0,
        color: const Color(0xFF2563EB), // Bleu royal
      );
    } else if (count >= 5) {
      return ClusterStyle(
        size: 55.0,
        fontSize: 15.0,
        color: const Color(0xFF7C3AED), // Violet
      );
    } else {
      return ClusterStyle(
        size: 50.0,
        fontSize: 14.0,
        color: const Color(0xFF0891B2), // Cyan
      );
    }
  }

  /// Compter les types dans un cluster
  static Map<String, int> _getTypeCounts(List<Construction> constructions) {
    final Map<String, int> counts = {};
    for (var construction in constructions) {
      counts[construction.type] = (counts[construction.type] ?? 0) + 1;
    }
    return counts;
  }

  /// Obtenir l'icône selon le type
  static IconData _getIconForType(String type) {
    switch (type) {
      case 'Résidentiel':
        return Icons.home;
      case 'Commercial':
        return Icons.store;
      case 'Industriel':
        return Icons.factory;
      case 'Public':
        return Icons.account_balance;
      default:
        return Icons.location_on;
    }
  }
}

/// Modèle pour un marqueur de cluster
class ClusterMarker {
  final LatLng position;
  final List<Construction> constructions;
  final bool isCluster;

  ClusterMarker({
    required this.position,
    required this.constructions,
    required this.isCluster,
  });

  int get count => constructions.length;
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
