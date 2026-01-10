import 'package:flutter/material.dart';
import '../models/construction.dart';

/// Popup riche pour afficher les informations d'une construction
/// 
/// Affiche un bottom sheet avec :
/// - En-tête avec icône et type coloré
/// - Informations détaillées (adresse, contact, superficie)
/// - Boutons d'action (Centrer, Modifier, Supprimer)
/// 
/// Design Material 3 avec coins arrondis et ombres
class ConstructionPopup extends StatelessWidget {
  /// La construction à afficher
  final Construction construction;
  
  /// Callback pour centrer la carte sur cette construction
  final VoidCallback onCenter;
  
  /// Callback pour modifier la construction
  final VoidCallback? onEdit;
  
  /// Callback pour supprimer la construction
  final VoidCallback onDelete;
  
  /// Callback pour fermer le popup
  final VoidCallback onClose;

  const ConstructionPopup({
    super.key,
    required this.construction,
    required this.onCenter,
    this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  /// Afficher le popup sous forme de bottom sheet
  static void show(
    BuildContext context, {
    required Construction construction,
    required VoidCallback onCenter,
    VoidCallback? onEdit,
    required VoidCallback onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ConstructionPopup(
        construction: construction,
        onCenter: () {
          Navigator.pop(ctx);
          onCenter();
        },
        onEdit: onEdit != null
            ? () {
                Navigator.pop(ctx);
                onEdit();
              }
            : null,
        onDelete: () {
          Navigator.pop(ctx);
          onDelete();
        },
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForType(construction.type);
    final icon = _getIconForType(construction.type);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête coloré
          _buildHeader(context, color, icon),
          
          // Corps avec informations
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Informations
                _buildInfoSection(),
                
                const SizedBox(height: 20),
                
                // Boutons d'action
                _buildActions(context, color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// En-tête avec gradient et icône
  Widget _buildHeader(BuildContext context, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              // Icône du type
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              
              // Type et géométrie
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      construction.type,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          construction.isValidPolygon()
                              ? Icons.pentagon_outlined
                              : Icons.location_on_outlined,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          construction.isValidPolygon()
                              ? '${construction.getPolygonPoints().length} sommets'
                              : 'Point GPS',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        if (construction.isValidPolygon()) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.square_foot,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${construction.getArea().toStringAsFixed(0)} m²',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Bouton fermer
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section des informations détaillées
  Widget _buildInfoSection() {
    return Column(
      children: [
        // Adresse
        _InfoRow(
          icon: Icons.location_on,
          label: 'Adresse',
          value: construction.adresse,
          color: Colors.red,
        ),
        const SizedBox(height: 16),
        
        // Contact
        _InfoRow(
          icon: Icons.person,
          label: 'Contact',
          value: construction.contact,
          color: Colors.blue,
        ),
        
        // Coordonnées GPS (centroïde)
        if (construction.isValidPolygon()) ...[
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.gps_fixed,
            label: 'Centroïde',
            value: _formatCoordinates(construction.getCentroid()),
            color: Colors.green,
          ),
        ],
      ],
    );
  }

  /// Formatter les coordonnées en texte lisible
  String _formatCoordinates(dynamic centroid) {
    try {
      return '${centroid.latitude.toStringAsFixed(6)}, ${centroid.longitude.toStringAsFixed(6)}';
    } catch (e) {
      return 'Non disponible';
    }
  }

  /// Section des boutons d'action
  Widget _buildActions(BuildContext context, Color color) {
    return Column(
      children: [
        // Bouton centrer (principal)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onCenter,
            icon: const Icon(Icons.center_focus_strong),
            label: const Text('Centrer sur la carte'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Boutons secondaires
        Row(
          children: [
            // Bouton modifier (si disponible)
            if (onEdit != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            
            // Bouton supprimer
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Obtenir la couleur pour un type de construction
  Color _getColorForType(String type) {
    switch (type) {
      case 'Résidentiel':
        return Colors.red;
      case 'Commercial':
        return Colors.blue;
      case 'Industriel':
        return Colors.orange;
      case 'Public':
        return Colors.green;
      default:
        return Colors.purple;
    }
  }

  /// Obtenir l'icône pour un type de construction
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
}

/// Ligne d'information avec icône, label et valeur
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icône dans un cercle
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        
        // Label et valeur
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
