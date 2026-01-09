import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Pour le GPS
import '../db/database_helper.dart'; // Pour sauvegarder
import '../models/construction.dart'; // Notre modèle de données

class AddConstructionScreen extends StatefulWidget {
  const AddConstructionScreen({super.key});

  @override
  State<AddConstructionScreen> createState() => _AddConstructionScreenState();
}

class _AddConstructionScreenState extends State<AddConstructionScreen> {
  // Une clé pour valider le formulaire (vérifier qu'il n'est pas vide)
  final _formKey = GlobalKey<FormState>();

  // Ces contrôleurs servent à lire ce que l'utilisateur écrit
  final _adresseController = TextEditingController();
  final _contactController = TextEditingController();

  // Valeur par défaut du menu déroulant
  String _selectedType = 'Résidentiel';

  // Variables pour stocker la position GPS
  String _currentPosition = "";
  bool _isLoading = false; // Pour afficher un petit chargement pendant la recherche GPS

  // --- FONCTION 1 : RÉCUPÉRER LE GPS ---
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true); // On montre que ça charge

    // 1. On vérifie si on a le droit d'utiliser le GPS
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Si l'utilisateur refuse, on arrête
        setState(() => _isLoading = false);
        return;
      }
    }

    // 2. On demande la position actuelle au téléphone
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
    );

    // 3. On met à jour l'écran avec les coordonnées
    setState(() {
      // On sauvegarde sous forme "latitude,longitude" (ex: 33.57, -7.58)
      _currentPosition = "${position.latitude},${position.longitude}";
      _isLoading = false; // Fini de charger
    });
  }

  // --- FONCTION 2 : SAUVEGARDER DANS LA BASE DE DONNÉES ---
  // --- REMPLACE TOUTE LA FONCTION _saveConstruction PAR CELLE-CI ---
  Future<void> _saveConstruction() async {
    print("1. Bouton Enregistrer cliqué"); // Debug

    // Vérifie si les champs texte sont remplis
    if (_formKey.currentState!.validate()) {
      print("2. Formulaire valide (Texte OK)"); // Debug

      // Vérifie si le GPS a été capturé
      if (_currentPosition.isEmpty) {
        print("ERREUR : Pas de position GPS"); // Debug
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ERREUR: Il faut cliquer sur "Capturer ma position" avant !')),
        );
        return;
      }

      print("3. Position GPS OK : $_currentPosition"); // Debug

      try {
        final newConstruction = Construction(
          adresse: _adresseController.text,
          contact: _contactController.text,
          type: _selectedType,
          geom: _currentPosition,
        );

        print("4. Envoi à la base de données..."); // Debug
        await DatabaseHelper.instance.create(newConstruction);

        print("5. Sauvegarde réussie ! Fermeture..."); // Debug

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        print("ERREUR GRAVE PENDANT LA SAUVEGARDE : $e"); // Debug
      }
    } else {
      print("ERREUR : Le formulaire n'est pas valide (champs vides ?)"); // Debug
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nouvelle Construction")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // ListView permet de scroller si le clavier cache l'écran
            children: [
              // Champ Adresse
              TextFormField(
                controller: _adresseController,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  border: OutlineInputBorder(), // Ajoute une bordure jolie
                ),
                validator: (value) => value!.isEmpty ? 'L\'adresse est requise' : null,
              ),
              const SizedBox(height: 15), // Espace vide

              // Champ Contact
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact (Propriétaire)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Le contact est requis' : null,
              ),
              const SizedBox(height: 15),

              // Menu déroulant (Dropdown)
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type de Construction',
                  border: OutlineInputBorder(),
                ),
                items: ['Résidentiel', 'Commercial', 'Industriel', 'Public']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 25),

              // Section GPS
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.grey[200], // Fond gris clair
                child: Column(
                  children: [
                    Text("Position GPS : ${_currentPosition.isEmpty ? 'Non définie' : _currentPosition}"),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _getCurrentLocation,
                      icon: const Icon(Icons.gps_fixed),
                      label: Text(_isLoading ? "Recherche..." : "Capturer ma position"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Gros bouton Enregistrer
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _saveConstruction,
                child: const Text("ENREGISTRER", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}