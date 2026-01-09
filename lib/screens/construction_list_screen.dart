import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/construction.dart';

class ConstructionListScreen extends StatefulWidget {
  const ConstructionListScreen({super.key});

  @override
  State<ConstructionListScreen> createState() => _ConstructionListScreenState();
}

class _ConstructionListScreenState extends State<ConstructionListScreen> {
  List<Construction> _allConstructions = [];
  List<Construction> _filteredConstructions = [];

  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await DatabaseHelper.instance.readAllConstructions();
    setState(() {
      _allConstructions = data;
      _filteredConstructions = data;
      _isLoading = false;
    });
  }

  void _runFilter(String enteredKeyword) {
    List<Construction> results = [];
    if (enteredKeyword.isEmpty) {
      // Si la recherche est vide, on réaffiche tout
      results = _allConstructions;
    } else {
      // Sinon, on filtre selon le Type OU l'Adresse
      results = _allConstructions
          .where((item) =>
      item.type.toLowerCase().contains(enteredKeyword.toLowerCase()) ||
          item.adresse.toLowerCase().contains(enteredKeyword.toLowerCase()))
          .toList();
    }

    // On met à jour l'affichage
    setState(() {
      _filteredConstructions = results;
    });
  }

  Color _getColor(String type) {
    switch (type) {
      case 'Résidentiel': return Colors.red;
      case 'Commercial': return Colors.blue;
      case 'Industriel': return Colors.orange;
      case 'Public': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recherche & Liste")),
      body: Column(
        children: [
          // --- BARRE DE RECHERCHE ---
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _runFilter(value),
              decoration: const InputDecoration(
                labelText: 'Rechercher (Type, Adresse...)',
                suffixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // --- LISTE DES RÉSULTATS ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredConstructions.isEmpty
                ? const Center(child: Text("Aucun résultat trouvé."))
                : ListView.builder(
              itemCount: _filteredConstructions.length,
              itemBuilder: (context, index) {
                final item = _filteredConstructions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getColor(item.type),
                      child: const Icon(Icons.home, color: Colors.white),
                    ),
                    title: Text(item.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("📍 ${item.adresse}\n👤 ${item.contact}"),
                    isThreeLine: true,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Retourne à la carte avec la position
                      Navigator.pop(context, item.geom);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}