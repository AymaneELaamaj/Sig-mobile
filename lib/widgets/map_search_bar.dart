import 'dart:async';
import 'package:flutter/material.dart';

/// Barre de recherche avec filtres pour la carte
/// 
/// Fonctionnalités :
/// - TextField avec debouncing (évite les recherches à chaque frappe)
/// - Chips de filtres cliquables par type de construction
/// - Compteur de résultats en temps réel
/// - Design Material 3 avec animations fluides
class MapSearchBar extends StatefulWidget {
  /// Callback appelé quand la recherche change (avec debouncing)
  final ValueChanged<String> onSearchChanged;
  
  /// Callback appelé quand un filtre de type est sélectionné/désélectionné
  final ValueChanged<String?> onTypeFilterChanged;
  
  /// Nombre total de résultats à afficher
  final int resultCount;
  
  /// Nombre total de constructions (sans filtre)
  final int totalCount;
  
  /// Filtre de type actuellement actif (null = tous)
  final String? activeTypeFilter;
  
  /// Map des couleurs par type
  final Map<String, Color> typeColors;

  const MapSearchBar({
    super.key,
    required this.onSearchChanged,
    required this.onTypeFilterChanged,
    required this.resultCount,
    required this.totalCount,
    this.activeTypeFilter,
    this.typeColors = const {
      'Résidentiel': Colors.red,
      'Commercial': Colors.blue,
      'Industriel': Colors.orange,
      'Public': Colors.green,
    },
  });

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  /// Contrôleur du champ de recherche
  final TextEditingController _controller = TextEditingController();
  
  /// Timer pour le debouncing
  Timer? _debounceTimer;
  
  /// Indique si la barre de recherche est en focus
  bool _isFocused = false;

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Gère le changement de texte avec debouncing
  /// 
  /// Attend 300ms après la dernière frappe avant d'appeler le callback
  /// Cela évite de faire des recherches à chaque caractère
  void _onTextChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.onSearchChanged(value);
    });
  }

  /// Efface le champ de recherche
  void _clearSearch() {
    _controller.clear();
    widget.onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barre de recherche principale
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // Champ de recherche
                Expanded(
                  child: Focus(
                    onFocusChange: (focused) {
                      setState(() => _isFocused = focused);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: _isFocused ? Colors.blue.withOpacity(0.05) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isFocused ? Colors.blue : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        onChanged: _onTextChanged,
                        decoration: InputDecoration(
                          hintText: 'Rechercher une adresse, un contact...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: Icon(
                            Icons.search,
                            color: _isFocused ? Colors.blue : Colors.grey[500],
                          ),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: _clearSearch,
                                  color: Colors.grey[500],
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Compteur de résultats
                if (widget.resultCount != widget.totalCount)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _ResultCounter(
                      count: widget.resultCount,
                      total: widget.totalCount,
                    ),
                  ),
              ],
            ),
          ),
          
          // Chips de filtres
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Chip "Tous"
                  _FilterChip(
                    label: 'Tous',
                    icon: Icons.select_all,
                    color: Colors.blue,
                    isSelected: widget.activeTypeFilter == null,
                    count: widget.totalCount,
                    onTap: () => widget.onTypeFilterChanged(null),
                  ),
                  const SizedBox(width: 8),
                  
                  // Chips par type
                  ...widget.typeColors.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: entry.key,
                        icon: _getIconForType(entry.key),
                        color: entry.value,
                        isSelected: widget.activeTypeFilter == entry.key,
                        onTap: () => widget.onTypeFilterChanged(
                          widget.activeTypeFilter == entry.key ? null : entry.key,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
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

/// Chip de filtre individuel
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final int? count;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey[800],
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.3) : color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compteur de résultats animé
class _ResultCounter extends StatelessWidget {
  final int count;
  final int total;

  const _ResultCounter({
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list, size: 14, color: Colors.blue[700]),
          const SizedBox(width: 4),
          Text(
            '$count/$total',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }
}
