import 'package:flutter/material.dart';

/// Widget de légende collapsible pour la carte
/// 
/// Affiche une légende qui peut être pliée/dépliée :
/// - État replié : affiche juste une icône compacte
/// - État déplié : affiche tous les types avec statistiques
/// 
/// Design Material 3 avec animations fluides
class CollapsibleLegendWidget extends StatefulWidget {
  /// Map des types de construction avec leurs couleurs
  final Map<String, Color> typeColors;
  
  /// Map des types avec leur nombre de constructions
  final Map<String, int> typeCounts;
  
  /// Indique si la légende est initialement dépliée
  final bool initiallyExpanded;
  
  /// Callback appelé quand on clique sur un type
  final ValueChanged<String>? onTypeTap;

  const CollapsibleLegendWidget({
    super.key,
    required this.typeColors,
    required this.typeCounts,
    this.initiallyExpanded = false,
    this.onTypeTap,
  });

  @override
  State<CollapsibleLegendWidget> createState() => _CollapsibleLegendWidgetState();
}

class _CollapsibleLegendWidgetState extends State<CollapsibleLegendWidget>
    with SingleTickerProviderStateMixin {
  /// Indique si la légende est dépliée
  late bool _isExpanded;
  
  /// Contrôleur d'animation pour la rotation de la flèche
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    if (_isExpanded) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Basculer l'état plié/déplié
  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  /// Calculer le total des constructions
  int get _totalCount => widget.typeCounts.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Material(
        elevation: 4,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(_isExpanded ? 16 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _isExpanded ? _buildExpandedContent() : _buildCollapsedContent(),
          ),
        ),
      ),
    );
  }

  /// Contenu quand la légende est repliée
  Widget _buildCollapsedContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icône de légende
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.legend_toggle,
            color: Colors.blue,
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        
        // Compteur total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$_totalCount',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        
        // Flèche animée
        RotationTransition(
          turns: _rotationAnimation,
          child: Icon(
            Icons.keyboard_arrow_up,
            color: Colors.grey[600],
            size: 20,
          ),
        ),
      ],
    );
  }

  /// Contenu quand la légende est dépliée
  Widget _buildExpandedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.legend_toggle,
                color: Colors.blue,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Légende',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            
            // Total
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    '$_totalCount total',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            
            // Flèche animée
            RotationTransition(
              turns: _rotationAnimation,
              child: Icon(
                Icons.keyboard_arrow_up,
                color: Colors.grey[600],
                size: 20,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        
        // Items de légende
        ...widget.typeColors.entries.map((entry) {
          final count = widget.typeCounts[entry.key] ?? 0;
          return _LegendItem(
            label: entry.key,
            color: entry.value,
            count: count,
            icon: _getIconForType(entry.key),
            onTap: widget.onTypeTap != null
                ? () => widget.onTypeTap!(entry.key)
                : null,
          );
        }),
      ],
    );
  }

  /// Retourne l'icône correspondant à un type de construction
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

/// Item individuel de la légende
class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  final IconData icon;
  final VoidCallback? onTap;

  const _LegendItem({
    required this.label,
    required this.color,
    required this.count,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône colorée dans un carré
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              
              // Label
              Text(
                label,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 10),
              
              // Compteur
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              
              // Indicateur de pourcentage
              if (count > 0) ...[
                const SizedBox(width: 6),
                _buildProgressBar(color, count),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color color, int count) {
    // Calculer un pourcentage relatif simplifié
    final percentage = (count / 10).clamp(0.1, 1.0);
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: percentage,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
