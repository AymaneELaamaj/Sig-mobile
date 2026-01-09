import 'package:flutter/material.dart';
import 'map_screen.dart'; // Pour pouvoir aller vers la carte après la connexion

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Contrôleurs pour récupérer ce que l'utilisateur écrit
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Clé pour vérifier le formulaire
  final _formKey = GlobalKey<FormState>();

  void _login() {
    // 1. On vérifie que les champs ne sont pas vides
    if (_formKey.currentState!.validate()) {

      // 2. Vérification du mot de passe (Compte de test)
      if (_usernameController.text == "admin" && _passwordController.text == "1234") {

        // 3. Si c'est bon, on change d'écran vers la Carte
        // "pushReplacement" empêche de revenir au login avec le bouton retour
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
        );
      } else {
        // 4. Sinon, on affiche une erreur en bas
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identifiant ou mot de passe incorrect'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView( // Permet de scroller si le clavier cache l'écran
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                const Icon(Icons.map_sharp, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  "SIG Mobile",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Text("Authentification Agent", style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 40),

                // Champ Identifiant
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: "Identifiant",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => value!.isEmpty ? "Veuillez entrer un identifiant" : null,
                ),
                const SizedBox(height: 20),

                // Champ Mot de passe
                TextFormField(
                  controller: _passwordController,
                  obscureText: true, // Cache le texte avec des points
                  decoration: const InputDecoration(
                    labelText: "Mot de passe",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) => value!.isEmpty ? "Veuillez entrer un mot de passe" : null,
                ),
                const SizedBox(height: 30),

                // Bouton Connexion
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _login,
                    child: const Text("SE CONNECTER", style: TextStyle(fontSize: 18)),
                  ),
                ),

                const SizedBox(height: 20),
                // Info pour tester
                const Text("Compte démo : admin / 1234", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}