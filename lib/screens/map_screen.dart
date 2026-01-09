import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Pour gérer la latitude/longitude
import '../db/database_helper.dart';
import '../models/construction.dart';
import 'add_construction_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Liste pour stocker les constructions récupérées de la base de données
  List<Construction> constructions = [];

  @override
  void initState() {
    super.initState();
    _refreshConstructions(); // Charger les données au démarrage
  }

  // Fonction pour lire la base de données
  Future<void> _refreshConstructions() async {
    final data = await DatabaseHelper.instance.readAllConstructions();
    setState(() {
      constructions = data;
    });
  }


  // Choisir la couleur selon le type
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

  LatLng _parseGeom(String geom) {
    try {
      final parts = geom.split(',');
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (e) {
      return const LatLng(33.5731, -7.5898); // Position par défaut si erreur
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIG Mobile - Carte'),
        actions: [
          // Bouton pour voir la liste (demandé dans le cahier des charges)
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {

            },
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          // Centre initial de la carte (Casablanca par exemple, change les coordonnées si tu veux)
          initialCenter: LatLng(33.5731, -7.5898),
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.sig_mobile',
          ),

          MarkerLayer(
            markers: constructions.map((c) {
              return Marker(
                point: _parseGeom(c.geom),
                width: 40,
                height: 40,
                child: Icon(
                  Icons.location_on,
                  // On utilise notre nouvelle fonction pour la couleur
                  color: _getColorForType(c.type),
                  size: 40,
                ),
              );
            }).toList(),
          ),
        ],
      ),

      // Bouton flottant pour AJOUTER une nouvelle construction
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddConstructionScreen()),
          );

          // Si result est "true", ça veut dire qu'on a sauvegardé une nouvelle construction
          if (result == true) {
            // Alors on recharge la liste pour voir le nouveau point rouge
            _refreshConstructions();
          }
        },
      ),
    );
  }
}