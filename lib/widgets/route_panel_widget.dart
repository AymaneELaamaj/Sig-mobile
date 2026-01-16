import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/route_info.dart';
import '../services/routing_service.dart';

/// Widget panneau d'itinéraire
/// 
/// Affiche les informations de l'itinéraire calculé :
/// - Distance et durée estimée
/// - Sélecteur de mode de transport
/// - Instructions de navigation (optionnel)
/// - Boutons d'action (Démarrer navigation, Partager, Fermer)
class RoutePanel extends StatefulWidget {
  /// Information de l'itinéraire
  final RouteInfo routeInfo;
  
  /// Callback quand le mode de transport change
  final Function(TravelMode) onTravelModeChanged;
  
  /// Callback pour démarrer la navigation
  final VoidCallback? onStartNavigation;
  
  /// Callback pour partager l'itinéraire
  final VoidCallback? onShare;
  
  /// Callback pour fermer le panneau
  final VoidCallback onClose;
  
  /// Afficher les instructions détaillées
  final bool showInstructions;

  const RoutePanel({
    super.key,
    required this.routeInfo,
    required this.onTravelModeChanged,
    this.onStartNavigation,
    this.onShare,
    required this.onClose,
    this.showInstructions = false,
  });

  @override
  State<RoutePanel> createState() => _RoutePanelState();
}

class _RoutePanelState extends State<RoutePanel> {
  bool _showInstructions = false;

  @override
  void initState() {
    super.initState();
    _showInstructions = widget.showInstructions;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // En-tête avec distance et durée
          _buildHeader(),
          
          // Sélecteur de mode de transport
          _buildTravelModeSelector(),
          
          // Informations supplémentaires
          _buildRouteDetails(),
          
          // Toggle instructions
          if (widget.routeInfo.instructions.isNotEmpty)
            _buildInstructionsToggle(),
          
          // Instructions détaillées
          if (_showInstructions && widget.routeInfo.instructions.isNotEmpty)
            _buildInstructions(),
          
          // Boutons d'action
          _buildActions(),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// En-tête avec distance, durée et heure d'arrivée
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Icône du mode de transport
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                widget.routeInfo.travelMode.emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Distance et durée
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.routeInfo.formattedDuration,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
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
                        widget.routeInfo.formattedDistance,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Arrivée estimée: ${widget.routeInfo.estimatedArrival}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Bouton fermer
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[100],
            ),
          ),
        ],
      ),
    );
  }

  /// Sélecteur de mode de transport
  Widget _buildTravelModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: TravelMode.values.map((mode) {
          final isSelected = widget.routeInfo.travelMode == mode;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => widget.onTravelModeChanged(mode),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        mode.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mode.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Détails de l'itinéraire
  Widget _buildRouteDetails() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildDetailItem(
              icon: Icons.route,
              label: 'Distance',
              value: widget.routeInfo.formattedDistance,
              color: Colors.blue,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[300],
            ),
            _buildDetailItem(
              icon: Icons.timer_outlined,
              label: 'Durée',
              value: widget.routeInfo.formattedDuration,
              color: Colors.green,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[300],
            ),
            _buildDetailItem(
              icon: Icons.schedule,
              label: 'Arrivée',
              value: widget.routeInfo.estimatedArrival,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Toggle pour afficher/masquer les instructions
  Widget _buildInstructionsToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () {
          setState(() {
            _showInstructions = !_showInstructions;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _showInstructions ? Colors.blue[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _showInstructions
                    ? Icons.expand_less
                    : Icons.directions,
                color: _showInstructions ? Colors.blue : Colors.grey[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _showInstructions
                    ? 'Masquer les instructions'
                    : 'Voir les instructions (${widget.routeInfo.instructions.length} étapes)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _showInstructions ? Colors.blue : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Liste des instructions de navigation
  Widget _buildInstructions() {
    return Container(
      margin: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        itemCount: widget.routeInfo.instructions.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          final instruction = widget.routeInfo.instructions[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: [
                // Icône de direction
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getInstructionColor(instruction.type),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    instruction.directionIcon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Texte de l'instruction
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        instruction.text,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (instruction.distanceMeters > 0)
                        Text(
                          instruction.formattedDistance,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getInstructionColor(String type) {
    switch (type) {
      case 'depart':
        return Colors.green;
      case 'arrive':
        return Colors.red;
      case 'turn':
        return Colors.blue;
      case 'roundabout':
      case 'rotary':
        return Colors.purple;
      default:
        return Colors.grey[600]!;
    }
  }

  /// Boutons d'action
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Bouton partager
          if (widget.onShare != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onShare,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Partager'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          
          if (widget.onShare != null && widget.onStartNavigation != null)
            const SizedBox(width: 12),
          
          // Bouton démarrer la navigation
          if (widget.onStartNavigation != null)
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: widget.onStartNavigation,
                icon: const Icon(Icons.navigation),
                label: const Text('Démarrer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet pour afficher le panneau d'itinéraire
class RouteBottomSheet extends StatelessWidget {
  final RouteInfo routeInfo;
  final Function(TravelMode) onTravelModeChanged;
  final VoidCallback? onStartNavigation;
  final VoidCallback? onShare;
  final VoidCallback onClose;

  const RouteBottomSheet({
    super.key,
    required this.routeInfo,
    required this.onTravelModeChanged,
    this.onStartNavigation,
    this.onShare,
    required this.onClose,
  });

  static void show(
    BuildContext context, {
    required RouteInfo routeInfo,
    required Function(TravelMode) onTravelModeChanged,
    VoidCallback? onStartNavigation,
    VoidCallback? onShare,
    required VoidCallback onClose,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => RouteBottomSheet(
        routeInfo: routeInfo,
        onTravelModeChanged: onTravelModeChanged,
        onStartNavigation: onStartNavigation,
        onShare: onShare,
        onClose: () {
          Navigator.pop(ctx);
          onClose();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          margin: const EdgeInsets.all(16),
          child: RoutePanel(
            routeInfo: routeInfo,
            onTravelModeChanged: onTravelModeChanged,
            onStartNavigation: onStartNavigation,
            onShare: onShare,
            onClose: onClose,
            showInstructions: false,
          ),
        );
      },
    );
  }
}
