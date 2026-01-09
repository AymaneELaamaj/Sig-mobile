import 'package:flutter/material.dart';
import 'screens/login_screen.dart'; // On importe notre nouvel écran

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Projet SIG Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // C'EST ICI LE CHANGEMENT : On démarre sur LoginScreen
      home: const LoginScreen(),
    );
  }
}