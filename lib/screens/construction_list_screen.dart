import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../models/construction.dart';

/// Écran de liste des constructions avec recherche multicritères
/// 
/// Design Material 3 professionnel avec :
/// - Header avec statistiques animées
/// - Barre de recherche moderne avec debouncing
/// - Filtres par type avec chips colorés
/// - Cartes de construction avec design riche
/// - Animations et effets visuels
class ConstructionListScreen extends StatefulWidget {
  const ConstructionListScreen({super.key});

  @override
  State<ConstructionListScreen> createState() => _ConstructionListScreenState();
}

class _ConstructionListScreenState extends State<ConstructionListScreen>
    with SingleTickerProviderStateMixin {
  
  // ============================================
  // DONNÉES
  // ============================================
  
  /// Toutes les constructions
  List<Construction> _allConstructions = [];
  
  /// Constructions filtrées
  List<Construction> _filteredConstructions = [];

  // ============================================
  // ÉTATS
  // ============================================
  
  /// État de chargement
  bool _isLoading = true;
  
  /// Filtre par type sélectionné (null = tous)
  String? _selectedTypeFilter;

  // ============================================
  // CONTRÔLEURS
  // ============================================
  
  /// Contrôleur de recherche
  final TextEditingController _searchController = TextEditingController();
  
  /// Contrôleur d'animation pour le header
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // ============================================
  // CONSTANTES
  // ============================================
  
  /// Types disponibles avec couleurs et icônes
  static const Map<String, _TypeInfo> _typeInfos = {
    'Résidentiel': _TypeInfo(Colors.red, Icons.home, 'Habitations'),
    'Commercial': _TypeInfo(Colors.blue, Icons.business, 'Commerces'),
    'Industriel': _TypeInfo(Colors.orange, Icons.factory, 'Industries'),
    'Public': _TypeInfo(Colors.green, Icons.account_balance, 'Bâtiments publics'),
  };

  // ============================================
  // CYCLE DE VIE
  // ============================================

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ============================================
  // MÉTHODES DONNÉES
  // ============================================

  /// Charger les données depuis la base
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final data = await DatabaseHelper.instance.readAllConstructions();
      setState(() {
        _allConstructions = data;
        _filteredConstructions = data;
        _isLoading = false;
      });
      _animController.forward(from: 0);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur lors du chargement');
    }
  }

  /// Appliquer les filtres (recherche textuelle + type)
  void _applyFilters() {
    String keyword = _searchController.text.toLowerCase();
    
    List<Construction> results = _allConstructions.where((item) {
      // Filtre par type
      if (_selectedTypeFilter != null && item.type != _selectedTypeFilter) {
        return false;
      }

      // Filtre par mot-clé
      if (keyword.isNotEmpty) {
        bool matchesAddress = item.adresse.toLowerCase().contains(keyword);
        bool matchesContact = item.contact.toLowerCase().contains(keyword);
        bool matchesType = item.type.toLowerCase().contains(keyword);
        
        if (!matchesAddress && !matchesContact && !matchesType) {
          return false;
        }
      }

      return true;
    }).toList();

    setState(() {
      _filteredConstructions = results;
    });
  }

  /// Compter par type
  int _countByType(String type) {
    return _allConstructions.where((c) => c.type == type).length;
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
            Text(message),
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
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Naviguer vers la carte avec la construction sélectionnée
  void _navigateToMap(Construction construction) {
    HapticFeedback.lightImpact();
    Navigator.pop(context, construction);
  }

  /// Supprimer une construction avec confirmation stylisée
  Future<void> _deleteConstruction(Construction item) async {
    final typeInfo = _typeInfos[item.type];
    
    bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Icône d'avertissement
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever,
                color: Colors.red,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            
            // Titre
            const Text(
              'Supprimer cette construction ?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Détails de la construction
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (typeInfo?.color ?? Colors.grey).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      typeInfo?.icon ?? Icons.place,
                      color: typeInfo?.color ?? Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.type,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: typeInfo?.color ?? Colors.grey,
                          ),
                        ),
                        Text(
                          item.adresse,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Cette action est irréversible',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            
            // Boutons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.delete(item.id!);
        _loadData();
        _showSuccess('Construction supprimée');
      } catch (e) {
        _showError('Erreur lors de la suppression');
      }
    }
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar avec effet de scroll
          _buildSliverAppBar(),
          
          // Header avec statistiques
          SliverToBoxAdapter(
            child: _buildStatsHeader(),
          ),
          
          // Barre de recherche
          SliverToBoxAdapter(
            child: _buildSearchBar(),
          ),
          
          // Filtres
          SliverToBoxAdapter(
            child: _buildFilterChips(),
          ),
          
          // Compteur de résultats
          SliverToBoxAdapter(
            child: _buildResultCounter(),
          ),
          
          // Liste des constructions
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _filteredConstructions.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyState())
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return FadeTransition(
                              opacity: _fadeAnimation,
                              child: _buildConstructionCard(
                                _filteredConstructions[index],
                                index,
                              ),
                            );
                          },
                          childCount: _filteredConstructions.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  /// AppBar avec SliverAppBar
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Mes Constructions',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 50, bottom: 16),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.withOpacity(0.1),
                Colors.purple.withOpacity(0.05),
              ],
            ),
          ),
        ),
      ),
      actions: [
        // Bouton effacer filtres
        if (_selectedTypeFilter != null || _searchController.text.isNotEmpty)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.filter_alt_off, color: Colors.red, size: 20),
            ),
            tooltip: 'Effacer les filtres',
            onPressed: () {
              _searchController.clear();
              setState(() => _selectedTypeFilter = null);
              _applyFilters();
            },
          ),
        // Bouton refresh
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.refresh, color: Colors.blue, size: 20),
          ),
          tooltip: 'Actualiser',
          onPressed: _loadData,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Header avec statistiques par type
  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade600,
            Colors.purple.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.layers, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_allConstructions.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'constructions au total',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Stats par type
          Row(
            children: _typeInfos.entries.map((entry) {
              final count = _countByType(entry.key);
              return Expanded(
                child: _StatBadge(
                  label: entry.key.substring(0, 3),
                  count: count,
                  color: entry.value.color,
                  icon: entry.value.icon,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Barre de recherche moderne
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => _applyFilters(),
          decoration: InputDecoration(
            hintText: 'Rechercher par adresse, contact...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  /// Chips de filtres par type
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Chip "Tous"
            _FilterChipCustom(
              label: 'Tous',
              icon: Icons.select_all,
              color: Colors.blue,
              isSelected: _selectedTypeFilter == null,
              count: _allConstructions.length,
              onTap: () {
                setState(() => _selectedTypeFilter = null);
                _applyFilters();
              },
            ),
            const SizedBox(width: 10),
            
            // Chips par type
            ..._typeInfos.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _FilterChipCustom(
                  label: entry.key,
                  icon: entry.value.icon,
                  color: entry.value.color,
                  isSelected: _selectedTypeFilter == entry.key,
                  count: _countByType(entry.key),
                  onTap: () {
                    setState(() {
                      _selectedTypeFilter = 
                          _selectedTypeFilter == entry.key ? null : entry.key;
                    });
                    _applyFilters();
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Compteur de résultats avec indication du filtre actif
  Widget _buildResultCounter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.format_list_numbered, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 6),
                Text(
                  '${_filteredConstructions.length} résultat${_filteredConstructions.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          if (_selectedTypeFilter != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (_typeInfos[_selectedTypeFilter]?.color ?? Colors.grey)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _typeInfos[_selectedTypeFilter]?.icon ?? Icons.filter_alt,
                    size: 14,
                    color: _typeInfos[_selectedTypeFilter]?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _selectedTypeFilter!,
                    style: TextStyle(
                      color: _typeInfos[_selectedTypeFilter]?.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedTypeFilter = null);
                      _applyFilters();
                    },
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: _typeInfos[_selectedTypeFilter]?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search, size: 14, color: Colors.purple),
                  const SizedBox(width: 4),
                  Text(
                    '"${_searchController.text}"',
                    style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  /// État vide stylisé
  Widget _buildEmptyState() {
    final hasFilters = _selectedTypeFilter != null || _searchController.text.isNotEmpty;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters ? Icons.search_off : Icons.domain_disabled,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasFilters ? 'Aucun résultat' : 'Aucune construction',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters
                  ? 'Essayez avec d\'autres critères de recherche'
                  : 'Ajoutez votre première construction depuis la carte',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _selectedTypeFilter = null);
                  _applyFilters();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Réinitialiser les filtres'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Carte de construction professionnelle
  Widget _buildConstructionCard(Construction item, int index) {
    final typeInfo = _typeInfos[item.type];
    final color = typeInfo?.color ?? Colors.grey;
    final icon = typeInfo?.icon ?? Icons.place;
    final isPolygon = item.isValidPolygon();
    final pointCount = isPolygon ? item.getPolygonPoints().length : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: color.withOpacity(0.2),
        child: InkWell(
          onTap: () => _navigateToMap(item),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icône du type avec numéro
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withOpacity(0.2),
                            color.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    // Badge numéro
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 1.5),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Informations
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.type,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Badge polygone/point
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPolygon ? Icons.pentagon_outlined : Icons.location_on,
                                  size: 12,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$pointCount pts',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Adresse
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.adresse,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Contact
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.contact,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions verticales
                Column(
                  children: [
                    // Bouton carte
                    _ActionButton(
                      icon: Icons.map_outlined,
                      color: Colors.blue,
                      tooltip: 'Voir sur la carte',
                      onTap: () => _navigateToMap(item),
                    ),
                    const SizedBox(height: 8),
                    // Bouton supprimer
                    _ActionButton(
                      icon: Icons.delete_outline,
                      color: Colors.red,
                      tooltip: 'Supprimer',
                      onTap: () => _deleteConstruction(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// WIDGETS AUXILIAIRES
// ============================================

/// Information sur un type de construction
class _TypeInfo {
  final Color color;
  final IconData icon;
  final String description;

  const _TypeInfo(this.color, this.icon, this.description);
}

/// Badge de statistique dans le header
class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de filtre personnalisé
class _FilterChipCustom extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  const _FilterChipCustom({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[800],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.25) 
                      : color.withOpacity(0.15),
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
          ),
        ),
      ),
    );
  }
}

/// Bouton d'action circulaire
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
