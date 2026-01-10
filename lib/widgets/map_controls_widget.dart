import 'package:flutter/material.dart';

/// Widget de contrôles pour la carte
/// 
/// Affiche une colonne verticale de boutons pour :
/// - Recentrage GPS sur la position utilisateur
/// - Zoom avant (+) et arrière (-)
/// - Toggle visibilité des marqueurs
/// - Sélecteur de fonds de carte (layers)
/// 
/// Style Material Design 3 avec ombres et coins arrondis
class MapControlsWidget extends StatelessWidget {
  /// Callback pour le recentrage GPS
  final VoidCallback onGpsPressed;
  
  /// Callback pour le zoom avant
  final VoidCallback onZoomIn;
  
  /// Callback pour le zoom arrière
  final VoidCallback onZoomOut;
  
  /// Callback pour toggle la visibilité des marqueurs
  final VoidCallback onToggleMarkers;
  
  /// Callback pour ouvrir le sélecteur de layers
  final VoidCallback onLayerPressed;
  
  /// Indique si on est en train de localiser l'utilisateur
  final bool isLocating;
  
  /// Indique si les marqueurs sont visibles
  final bool markersVisible;

  const MapControlsWidget({
    super.key,
    required this.onGpsPressed,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onToggleMarkers,
    required this.onLayerPressed,
    this.isLocating = false,
    this.markersVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Bouton GPS / Ma position
          _ControlButton(
            icon: isLocating ? Icons.hourglass_top : Icons.my_location,
            tooltip: 'Ma position',
            onPressed: onGpsPressed,
            color: Colors.blue,
            isTop: true,
          ),
          
          const _Divider(),
          
          // Bouton Zoom +
          _ControlButton(
            icon: Icons.add,
            tooltip: 'Zoom avant',
            onPressed: onZoomIn,
          ),
          
          const _Divider(),
          
          // Bouton Zoom -
          _ControlButton(
            icon: Icons.remove,
            tooltip: 'Zoom arrière',
            onPressed: onZoomOut,
          ),
          
          const _Divider(),
          
          // Toggle visibilité marqueurs
          _ControlButton(
            icon: markersVisible ? Icons.visibility : Icons.visibility_off,
            tooltip: markersVisible ? 'Masquer les marqueurs' : 'Afficher les marqueurs',
            onPressed: onToggleMarkers,
            color: markersVisible ? Colors.green : Colors.grey,
          ),
          
          const _Divider(),
          
          // Sélecteur de layers
          _ControlButton(
            icon: Icons.layers,
            tooltip: 'Fond de carte',
            onPressed: onLayerPressed,
            color: Colors.deepPurple,
            isBottom: true,
          ),
        ],
      ),
    );
  }
}

/// Bouton individuel de contrôle
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;
  final bool isTop;
  final bool isBottom;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = Colors.black87,
    this.isTop = false,
    this.isBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.vertical(
            top: isTop ? const Radius.circular(16) : Radius.zero,
            bottom: isBottom ? const Radius.circular(16) : Radius.zero,
          ),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}

/// Diviseur fin entre les boutons
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 1,
      color: Colors.grey[200],
    );
  }
}

/// Enumération des types de fonds de carte disponibles
enum MapLayerType {
  standard('Standard', Icons.map, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
  satellite('Satellite', Icons.satellite_alt, 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
  terrain('Terrain', Icons.terrain, 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png'),
  dark('Sombre', Icons.dark_mode, 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png');

  final String label;
  final IconData icon;
  final String tileUrl;

  const MapLayerType(this.label, this.icon, this.tileUrl);
}

/// Bottom sheet pour sélectionner le fond de carte
class LayerSelectorSheet extends StatelessWidget {
  final MapLayerType currentLayer;
  final ValueChanged<MapLayerType> onLayerChanged;

  const LayerSelectorSheet({
    super.key,
    required this.currentLayer,
    required this.onLayerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Titre
          const Row(
            children: [
              Icon(Icons.layers, color: Colors.deepPurple),
              SizedBox(width: 12),
              Text(
                'Fond de carte',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Options de layers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: MapLayerType.values.map((layer) {
              final isSelected = currentLayer == layer;
              return _LayerOption(
                layer: layer,
                isSelected: isSelected,
                onTap: () {
                  onLayerChanged(layer);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Option individuelle de layer
class _LayerOption extends StatelessWidget {
  final MapLayerType layer;
  final bool isSelected;
  final VoidCallback onTap;

  const _LayerOption({
    required this.layer,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          children: [
            // Icône dans un cercle
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepPurple : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.deepPurple : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                layer.icon,
                color: isSelected ? Colors.white : Colors.grey[700],
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            
            // Label
            Text(
              layer.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.deepPurple : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
