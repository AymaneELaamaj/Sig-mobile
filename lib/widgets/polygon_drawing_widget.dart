import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/geojson_helper.dart';

/// Widget pour dessiner des polygones sur la carte
/// Permet à l'utilisateur de placer des points en cliquant sur la carte
class PolygonDrawingWidget extends StatefulWidget {
  final MapController mapController;
  final Function(String geoJson) onPolygonCompleted;
  final Function() onCancel;
  final Color polygonColor;

  const PolygonDrawingWidget({
    super.key,
    required this.mapController,
    required this.onPolygonCompleted,
    required this.onCancel,
    this.polygonColor = Colors.blue,
  });

  @override
  State<PolygonDrawingWidget> createState() => _PolygonDrawingWidgetState();
}

class _PolygonDrawingWidgetState extends State<PolygonDrawingWidget> {
  // Liste des points du polygone en cours de dessin
  List<LatLng> _polygonPoints = [];
  
  // Messages d'erreur
  String? _errorMessage;

  /// Ajouter un point au polygone
  void addPoint(LatLng point) {
    setState(() {
      _polygonPoints.add(point);
      _errorMessage = null;
    });
  }

  /// Supprimer le dernier point
  void removeLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
        _errorMessage = null;
      });
    }
  }

  /// Réinitialiser le dessin
  void resetDrawing() {
    setState(() {
      _polygonPoints.clear();
      _errorMessage = null;
    });
  }

  /// Valider et terminer le polygone
  void completePolygon() {
    // Vérification du nombre minimum de points
    if (_polygonPoints.length < 3) {
      setState(() {
        _errorMessage = 'Un polygone doit avoir au moins 3 points';
      });
      return;
    }

    // Vérification d'auto-intersection
    if (GeoJsonHelper.isSelfIntersecting(_polygonPoints)) {
      setState(() {
        _errorMessage = 'Le polygone ne doit pas se croiser lui-même';
      });
      return;
    }

    // Convertir en GeoJSON et retourner
    try {
      String geoJson = GeoJsonHelper.pointsToGeoJson(_polygonPoints);
      widget.onPolygonCompleted(geoJson);
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la création du polygone: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Couche de dessin sur la carte (détection des taps)
        Positioned.fill(
          child: GestureDetector(
            onTapUp: (details) {
              // Convertir la position de l'écran en coordonnées géographiques
              final RenderBox renderBox = context.findRenderObject() as RenderBox;
              final localPosition = renderBox.globalToLocal(details.globalPosition);
              
              // Utiliser le MapController pour convertir
              final point = widget.mapController.camera.pointToLatLng(
                Point(localPosition.dx, localPosition.dy),
              );
              
              addPoint(point);
            },
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),

        // Panneau d'instructions en haut
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.draw, color: widget.polygonColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Mode Dessin de Polygone',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Touchez la carte pour placer les sommets du polygone.\n'
                  'Points placés : ${_polygonPoints.length} / 3 minimum',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Boutons de contrôle en bas
        Positioned(
          bottom: 20,
          left: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Bouton Annuler
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      resetDrawing();
                      widget.onCancel();
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Annuler'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Bouton Supprimer dernier point
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _polygonPoints.isEmpty ? null : removeLastPoint,
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Retour'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Bouton Valider
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _polygonPoints.length >= 3 ? completePolygon : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Obtenir les layers à afficher sur la carte
  /// Cette méthode doit être appelée depuis le widget parent
  List<Widget> getMapLayers() {
    List<Widget> layers = [];

    // Afficher les marqueurs pour chaque point
    if (_polygonPoints.isNotEmpty) {
      layers.add(
        MarkerLayer(
          markers: _polygonPoints.asMap().entries.map((entry) {
            int index = entry.key;
            LatLng point = entry.value;
            return Marker(
              point: point,
              width: 30,
              height: 30,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.polygonColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );

      // Afficher les lignes entre les points
      if (_polygonPoints.length >= 2) {
        // Ligne du polygone (en cours de dessin)
        List<LatLng> polylinePoints = List.from(_polygonPoints);
        
        layers.add(
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylinePoints,
                strokeWidth: 3,
                color: widget.polygonColor,
              ),
              // Ligne de fermeture en pointillés (si >= 3 points)
              if (_polygonPoints.length >= 3)
                Polyline(
                  points: [_polygonPoints.last, _polygonPoints.first],
                  strokeWidth: 2,
                  color: widget.polygonColor.withOpacity(0.5),
                  isDotted: true,
                ),
            ],
          ),
        );
      }

      // Afficher le polygone rempli si >= 3 points
      if (_polygonPoints.length >= 3) {
        layers.insert(
          0, // Insérer en premier pour que les marqueurs soient au-dessus
          PolygonLayer(
            polygons: [
              Polygon(
                points: _polygonPoints,
                color: widget.polygonColor.withOpacity(0.2),
                borderColor: widget.polygonColor,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        );
      }
    }

    return layers;
  }

  /// Obtenir les points actuels
  List<LatLng> get points => List.unmodifiable(_polygonPoints);
}
