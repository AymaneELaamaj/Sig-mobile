# 📱 Application SIG Mobile - Documentation Complète pour Soutenance

> **Projet académique 2025-2026** - Développement d'une application mobile de relevé cartographique  
> **Enseignant** : LOTF HAMZA  
> **Technologies** : Flutter, SQLite, flutter_map  

---

## 📑 Table des Matières

1. [Vue d'ensemble du projet](#-vue-densemble-du-projet)
2. [Architecture du projet](#-architecture-du-projet)
3. [Structure des dossiers expliquée](#-structure-des-dossiers-expliquée)
4. [Explication fichier par fichier](#-explication-fichier-par-fichier)
5. [Flux de données et navigation](#-flux-de-données-et-navigation)
6. [Concepts Flutter utilisés](#-concepts-flutter-utilisés)
7. [Base de données SQLite](#-base-de-données-sqlite)
8. [Questions fréquentes de soutenance](#-questions-fréquentes-de-soutenance)
9. [Schémas et diagrammes](#-schémas-et-diagrammes)
10. [Comment lancer le projet](#-installation-et-lancement)

---

## 🎯 Vue d'ensemble du projet

### Qu'est-ce qu'une application SIG ?

Un **SIG (Système d'Information Géographique)** est un système qui permet de :
- **Capturer** des données géographiques (où sont les choses)
- **Stocker** ces informations dans une base de données
- **Analyser** et **visualiser** ces données sur une carte
- **Partager** l'information avec d'autres personnes

**Analogie simple** : C'est comme Google Maps, mais au lieu de juste voir les routes, on peut ajouter nos propres informations (immeubles, magasins, etc.).

### Objectif de notre application

Notre application aide les **agents d'agence urbaine** à :
1. **Sortir sur le terrain** avec leur téléphone
2. **Dessiner les contours** des bâtiments sur une carte
3. **Remplir un formulaire** avec les informations (adresse, propriétaire, type)
4. **Sauvegarder tout** dans le téléphone même sans internet
5. **Consulter** plus tard toutes les données collectées

### Fonctionnalités principales

✅ **Authentification** - Seuls les agents autorisés peuvent utiliser l'app  
✅ **Dessin de polygones** - Tracer les contours exacts des bâtiments  
✅ **Formulaire de saisie** - Enregistrer les détails de chaque construction  
✅ **Carte interactive** - Visualiser toutes les constructions avec des couleurs  
✅ **Liste et recherche** - Retrouver rapidement une construction  
✅ **Base de données locale** - Tout fonctionne sans internet  

### Technologies utilisées et pourquoi

| Technologie | Rôle | Pourquoi ce choix |
|-------------|------|-------------------|
| **Flutter** | Framework pour créer l'app mobile | Une seule codebase pour Android, iOS et Windows |
| **SQLite** | Base de données locale | Fonctionne sans internet, rapide, intégrée |
| **flutter_map** | Affichage de cartes | Alternative gratuite à Google Maps |
| **geolocator** | GPS et localisation | Pour obtenir la position actuelle |
| **latlong2** | Calculs géographiques | Convertir coordonnées, calculer distances |

### Public cible

**Agents d'agence urbaine** qui travaillent sur le terrain pour :
- Faire le recensement des constructions
- Mettre à jour les plans d'urbanisme
- Contrôler les permis de construire

---

## 🏗️ Architecture du projet

### Pourquoi organiser le code en dossiers ?

Imagine que ton code soit comme une **bibliothèque** :
- Si tous les livres étaient mélangés, impossible de retrouver quoi que ce soit
- Avec des **rayons organisés** (Romans, Sciences, Histoire...), c'est facile !

Pareil pour le code : chaque dossier a un **rôle précis**.

### Principe de séparation des responsabilités

Chaque partie du code a **UNE seule mission** :
- Les **Screens** s'occupent uniquement d'afficher l'interface
- Les **Models** définissent la structure des données
- Les **Utils** font les calculs complexes
- La **Database** gère la sauvegarde

### Schéma de l'architecture

```
┌─────────────────────────────────────────┐
│           UTILISATEUR                    │
│  (Appuie sur boutons, voit l'écran)     │
└──────────────┬──────────────────────────┘
               │ Interactions (tap, swipe)
               ▼
┌─────────────────────────────────────────┐
│         COUCHE UI (Screens)              │
│  LoginScreen, MapScreen, ListScreen...   │
│  → Affiche les données                   │
│  → Réagit aux interactions               │
└──────────────┬──────────────────────────┘
               │ Appels de méthodes
               ▼
┌─────────────────────────────────────────┐
│      COUCHE LOGIQUE (Models + Utils)     │
│  Construction.dart, GeoJsonHelper...     │
│  → Définit la structure des données      │
│  → Fait les calculs (GeoJSON, centroïd) │
│  → Validation des données                │
└──────────────┬──────────────────────────┘
               │ Requêtes SQL
               ▼
┌─────────────────────────────────────────┐
│    COUCHE DONNÉES (Database)             │
│  DatabaseHelper                          │
│  → CRUD (Create, Read, Update, Delete)   │
│  → Communication avec SQLite             │
└──────────────┬──────────────────────────┘
               │ Fichier de base de données
               ▼
┌─────────────────────────────────────────┐
│         SQLite Database                  │
│  (Fichier .db stocké sur le téléphone)  │
└─────────────────────────────────────────┘
```

### Flux de données

**Exemple** : L'utilisateur veut ajouter une construction

1. **UI** → Utilisateur dessine sur la carte et remplit le formulaire
2. **Models** → Les données sont structurées en objet `Construction`
3. **Utils** → Les points GPS sont convertis en GeoJSON
4. **Database** → L'objet est sauvegardé dans SQLite
5. **Database → UI** → L'écran se met à jour avec la nouvelle construction

---

## 📁 Structure des dossiers expliquée

```
lib/
├── main.dart                    # Point d'entrée de l'application
├── db/                         # Tout ce qui concerne la base de données
│   └── database_helper.dart    # Gestion SQLite (CRUD)
├── models/                     # Définition des objets métier
│   └── construction.dart       # Structure d'une construction
├── screens/                    # Les écrans de l'application
│   ├── login_screen.dart       # Écran de connexion
│   ├── map_screen.dart         # Écran principal avec la carte
│   ├── add_construction_screen.dart  # Écran d'ajout
│   └── construction_list_screen.dart # Écran de liste
├── utils/                      # Fonctions utilitaires réutilisables
│   ├── geojson_helper.dart     # Gestion du format GeoJSON
│   └── map_helper.dart         # Calculs de carte (centrage, zoom)
└── widgets/                    # Composants d'interface réutilisables
    └── polygon_drawing_widget.dart # Widget pour dessiner des polygones
```

### Explication détaillée de chaque dossier

#### 📂 `db/` - Base de données
**Rôle** : Gérer toute la communication avec SQLite  
**Analogie** : C'est le "bibliothécaire" qui sait où ranger et retrouver chaque livre  
**Contient** : `database_helper.dart`  
**Quand on y touche** : Si on veut changer la structure de la base, ajouter une nouvelle table, modifier une requête SQL

#### 📂 `models/` - Modèles de données  
**Rôle** : Définir la structure des objets qu'on manipule  
**Analogie** : C'est le "formulaire vierge" qui dit quels champs doit avoir une construction  
**Contient** : `construction.dart`  
**Quand on y touche** : Si on veut ajouter de nouveaux champs (ex: hauteur du bâtiment, nombre d'étages)

#### 📂 `screens/` - Écrans de l'application  
**Rôle** : Tout ce que voit l'utilisateur  
**Analogie** : Ce sont les "pages" du livre, chacune avec son contenu spécifique  
**Contient** : Les 4 écrans principaux  
**Quand on y touche** : Pour changer l'apparence, ajouter des boutons, modifier le comportement des écrans

#### 📂 `utils/` - Utilitaires  
**Rôle** : Fonctions de calcul réutilisables  
**Analogie** : C'est la "calculatrice" et la "règle" pour faire des mesures précises  
**Contient** : Helpers pour GeoJSON et carte  
**Quand on y touche** : Pour ajouter de nouveaux calculs, améliorer les algorithmes existants

#### 📂 `widgets/` - Composants réutilisables  
**Rôle** : Petits éléments d'interface qu'on peut réutiliser  
**Analogie** : Ce sont les "briques LEGO" qu'on peut assembler pour construire des écrans  
**Contient** : Widget de dessin de polygones  
**Quand on y touche** : Pour créer de nouveaux composants réutilisables

---

## 📋 Explication fichier par fichier

### 🎯 `main.dart` - Point d'entrée

**Rôle** : C'est le "démarrage" de l'application, comme l'interrupteur principal  

**Ce qu'il fait** :
- Configure l'apparence générale (thème, couleurs)
- Définit quel écran s'affiche au lancement (`LoginScreen`)
- Désactive le bandeau "Debug" en mode développement

**Code clé expliqué** :
```dart
void main() {
  runApp(const MyApp());  // Lance l'application
}

home: const LoginScreen(),  // Premier écran = connexion
```

### 🔐 `lib/screens/login_screen.dart` - Authentification

**Rôle** : Vérifier l'identité de l'utilisateur avant d'accéder à l'app

**Ce qu'il contient** :
- 2 champs de texte (identifiant + mot de passe)
- Validation des champs (pas vides)
- Vérification des identifiants
- Navigation vers `MapScreen` si OK

**Concepts Flutter utilisés** :
- `StatefulWidget` : Pour gérer l'état des champs
- `TextEditingController` : Pour récupérer le texte saisi
- `Form` + `GlobalKey` : Pour valider le formulaire
- `Navigator.pushReplacement` : Changer d'écran sans retour possible

**Code clé expliqué** :
```dart
// Vérification simple des identifiants
if (_usernameController.text == "admin" && _passwordController.text == "1234") {
  Navigator.pushReplacement(context, MaterialPageRoute(...));
}
```

### 🗺️ `lib/screens/map_screen.dart` - Écran principal

**Rôle** : C'est le "tableau de bord" principal - affiche la carte avec toutes les constructions

**Ce qu'il contient** :
- Carte interactive (flutter_map)
- Affichage des constructions (polygones colorés + marqueurs)
- Navigation vers les autres écrans
- Légende des couleurs
- Popup d'information au clic

**Concepts Flutter utilisés** :
- `FlutterMap` : Widget de carte
- `PolygonLayer` : Pour dessiner les surfaces
- `MarkerLayer` : Pour placer des icônes
- `showModalBottomSheet` : Popup depuis le bas
- `setState()` : Mise à jour de l'affichage

**Code clé expliqué** :
```dart
// Afficher les constructions sur la carte
PolygonLayer(
  polygons: _buildPolygons(),  // Construire la liste des polygones
)

// Centrer la carte sur une construction
void _centerOnConstruction(Construction construction) {
  LatLng centroid = construction.getCentroid();
  _mapController.move(centroid, zoom);
}
```

### ➕ `lib/screens/add_construction_screen.dart` - Ajout de construction

**Rôle** : Permet de créer une nouvelle construction (dessin + formulaire)

**Ce qu'il contient** :
- Carte pour dessiner le polygone (partie haute)
- Formulaire de saisie (partie basse)
- Validation du polygone (minimum 3 points)
- Détection GPS
- Sauvegarde en base

**Concepts Flutter utilisés** :
- `Column` avec `Expanded` : Diviser l'écran en 2
- Gestion des taps sur la carte
- `GestureDetector` : Détecter les touches sur la carte
- `Form` validation : Vérifier les champs avant sauvegarde

**Code clé expliqué** :
```dart
// Ajouter un point au polygone quand on touche la carte
onTap: _isDrawingMode ? (tapPosition, point) => _addPoint(point) : null,

// Valider le polygone avant sauvegarde
if (_polygonPoints.length < 3) {
  _showError('Le polygone doit avoir au moins 3 points');
}
```

### 📋 `lib/screens/construction_list_screen.dart` - Liste et recherche

**Rôle** : Afficher toutes les constructions sous forme de liste avec recherche

**Ce qu'il contient** :
- Barre de recherche
- Filtres par type (chips)
- Liste des résultats (cards)
- Boutons d'action (voir sur carte, supprimer)

**Concepts Flutter utilisés** :
- `TextField` avec `onChanged` : Recherche en temps réel
- `FilterChip` : Boutons de filtre
- `ListView.builder` : Liste optimisée
- `RefreshIndicator` : Tirer pour actualiser

**Code clé expliqué** :
```dart
// Filtrer les constructions en temps réel
void _applyFilters() {
  List<Construction> results = _allConstructions.where((item) {
    // Filtrer par type ET par mot-clé
    return matchType && matchKeyword;
  }).toList();
}
```

### 🏠 `lib/models/construction.dart` - Modèle de données

**Rôle** : Définir ce qu'est une "construction" dans notre app

**Ce qu'il contient** :
- Les propriétés (id, adresse, contact, type, geom)
- Méthodes de conversion (vers/depuis la base)
- Méthodes utilitaires (getCentroid, getArea, etc.)

**Concepts Flutter utilisés** :
- `Class` : Définir un objet
- `factory constructor` : Créer un objet depuis une Map
- `Map<String, dynamic>` : Format utilisé par SQLite

**Code clé expliqué** :
```dart
// Structure de base
class Construction {
  final int? id;           // Clé primaire (auto-générée)
  final String adresse;    // Adresse du bâtiment
  final String contact;    // Nom du propriétaire
  final String type;       // Résidentiel, Commercial...
  final String geom;       // Coordonnées GPS au format GeoJSON
}

// Conversion pour SQLite
Map<String, dynamic> toMap() {
  return {'id': id, 'adresse': adresse, ...};
}
```

### 💾 `lib/db/database_helper.dart` - Base de données

**Rôle** : Gérer toute la communication avec SQLite (sauvegarde, lecture, suppression)

**Ce qu'il contient** :
- Ouverture/création de la base
- Opérations CRUD (Create, Read, Update, Delete)
- Requêtes de recherche
- Gestion des erreurs

**Concepts Flutter utilisés** :
- `Singleton pattern` : Une seule instance de la classe
- `async/await` : Opérations asynchrones
- `Future` : Opérations qui prennent du temps
- Requêtes SQL

**Code clé expliqué** :
```dart
// Créer la table au premier lancement
Future _createDB(Database db, int version) async {
  await db.execute('''
    CREATE TABLE constructions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      adresse TEXT NOT NULL,
      contact TEXT NOT NULL,
      type TEXT NOT NULL,
      geom TEXT NOT NULL
    )
  ''');
}

// Sauvegarder une construction
Future<int> create(Construction construction) async {
  final db = await instance.database;
  return await db.insert('constructions', construction.toMap());
}
```

### 🧮 `lib/utils/geojson_helper.dart` - Gestion GeoJSON

**Rôle** : Convertir les points GPS en format standard (GeoJSON) et faire des calculs

**Ce qu'il contient** :
- Conversion points → GeoJSON
- Conversion GeoJSON → points
- Calcul du centre d'un polygone
- Validation des polygones
- Calcul d'aire

**Pourquoi GeoJSON ?**  
C'est un **format standard** pour stocker des formes géographiques. Au lieu de stocker "point1, point2, point3...", on stocke une structure organisée que d'autres logiciels comprennent.

**Code clé expliqué** :
```dart
// Convertir des points en GeoJSON standard
static String pointsToGeoJson(List<LatLng> points) {
  // Structure GeoJSON officielle
  Map<String, dynamic> geoJson = {
    "type": "Polygon",
    "coordinates": [coordinates]  // Liste des points [lng, lat]
  };
  return jsonEncode(geoJson);
}

// Calculer le centre géométrique
static LatLng calculateCentroid(List<LatLng> points) {
  // Moyenne des latitudes et longitudes
  double sumLat = 0, sumLng = 0;
  for (var point in points) {
    sumLat += point.latitude;
    sumLng += point.longitude;
  }
  return LatLng(sumLat / points.length, sumLng / points.length);
}
```

### 🗺️ `lib/utils/map_helper.dart` - Utilitaires carte

**Rôle** : Fonctions pour manipuler la carte (centrage, zoom, calculs)

**Ce qu'il contient** :
- Calcul du zoom optimal pour un polygone
- Centrage automatique sur une construction  
- Détection point-dans-polygone
- Calcul des limites d'affichage

**Code clé expliqué** :
```dart
// Calculer le niveau de zoom selon la taille du polygone
static double calculateZoomForBounds(Map<String, double> bounds, ...) {
  double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
  // Plus le polygone est grand, plus le zoom est faible
  if (maxDiff < 0.001) return 18;  // Très proche
  if (maxDiff < 0.1) return 13;    // Moyen  
  return 10;                       // Très loin
}
```

### 🎨 `lib/widgets/polygon_drawing_widget.dart` - Dessin de polygones

**Rôle** : Composant réutilisable pour dessiner des polygones sur une carte

**Ce qu'il contient** :
- Interface de dessin (instructions, boutons)
- Gestion des points (ajout, suppression)
- Validation du polygone
- Feedback visuel (numérotation des points)

**Pourquoi un Widget séparé ?**  
Pour pouvoir **réutiliser** ce composant ailleurs dans l'app sans réécrire le code.

---

## 🔄 Flux de données et navigation

### Navigation entre écrans

```
LoginScreen (admin/1234)
    ↓ [Connexion réussie]
MapScreen (écran principal)
    ↓ [Bouton +]                    ↓ [Bouton liste]
AddConstructionScreen         ConstructionListScreen
    ↓ [Enregistrer]                  ↓ [Clic construction]
MapScreen (avec nouvelle)     MapScreen (centrée sur construction)
```

### Flux de données - Ajout d'une construction

1. **Utilisateur dessine** sur `AddConstructionScreen`
2. **Points GPS collectés** dans `List<LatLng>`
3. **Validation** par `GeoJsonHelper.isValidPolygon()`
4. **Conversion GeoJSON** par `GeoJsonHelper.pointsToGeoJson()`
5. **Création objet** `Construction(geom: geoJson, ...)`
6. **Sauvegarde** via `DatabaseHelper.create()`
7. **Retour** vers `MapScreen` avec rafraîchissement
8. **Affichage** du nouveau polygone sur la carte

### Flux de données - Recherche

1. **Utilisateur tape** dans `ConstructionListScreen`
2. **Filtre appliqué** sur `_allConstructions`
3. **Résultats mis à jour** via `setState()`
4. **Liste rafraîchie** automatiquement

### Gestion de l'état

| Écran | Type d'état | Données gérées |
|-------|-------------|----------------|
| `LoginScreen` | Local (`StatefulWidget`) | Champs du formulaire |
| `MapScreen` | Local + Base | Liste des constructions, construction sélectionnée |
| `AddConstructionScreen` | Local | Points du polygone, données formulaire |
| `ConstructionListScreen` | Local + Base | Liste filtrée, critères de recherche |

---

## 🎓 Concepts Flutter utilisés

### 1. StatefulWidget vs StatelessWidget

**StatelessWidget** : Ne change jamais (comme une photo)  
**StatefulWidget** : Peut changer d'apparence (comme un écran qui s'actualise)

```dart
// Notre app utilise StatefulWidget car on met à jour les données
class MapScreen extends StatefulWidget {
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Construction> constructions = [];  // ← État qui change
  
  void _refreshConstructions() {
    setState(() {  // ← Dire à Flutter de redessiner
      constructions = nouvelleDonnees;
    });
  }
}
```

### 2. Widgets de mise en page

| Widget | Utilisation dans notre app |
|--------|----------------------------|
| `Scaffold` | Structure de base de chaque écran (AppBar + Body) |
| `Column` | Empiler verticalement (formulaire d'ajout) |
| `Row` | Aligner horizontalement (boutons de contrôle) |
| `Expanded` | Prendre tout l'espace disponible (carte/formulaire 50/50) |
| `Stack` | Superposer des éléments (boutons sur la carte) |
| `Positioned` | Placer précisément dans un Stack |

### 3. Navigation

```dart
// Aller vers un nouvel écran
Navigator.push(context, MaterialPageRoute(builder: (context) => NouvelEcran()));

// Remplacer l'écran actuel (pas de retour possible)
Navigator.pushReplacement(context, MaterialRoute(...));

// Revenir à l'écran précédent avec des données
Navigator.pop(context, donnéesRetour);
```

### 4. Gestion des formulaires

```dart
final _formKey = GlobalKey<FormState>();

// Validation avant sauvegarde
if (_formKey.currentState!.validate()) {
  // Tous les champs sont OK
}

// Validation d'un champ
TextFormField(
  validator: (value) => value!.isEmpty ? 'Champ obligatoire' : null,
)
```

### 5. Programmation asynchrone

```dart
// Fonction qui prend du temps (base de données, GPS, internet)
Future<void> _loadData() async {
  setState(() => _isLoading = true);
  
  try {
    final data = await DatabaseHelper.instance.readAllConstructions();  // Attendre le résultat
    setState(() {
      constructions = data;
      _isLoading = false;
    });
  } catch (e) {
    // Gérer les erreurs
    _showError('Erreur: $e');
  }
}
```

---

## 💾 Base de données SQLite

### Pourquoi SQLite ?

✅ **Fonctionne hors ligne** - Pas besoin d'internet  
✅ **Rapide** - Données stockées directement sur le téléphone  
✅ **Fiable** - Technologie éprouvée utilisée partout  
✅ **Léger** - Prend peu d'espace  
✅ **SQL standard** - Langage de requête universel  

### Structure de notre base

```sql
CREATE TABLE constructions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,  -- Identifiant unique auto-généré
  adresse TEXT NOT NULL,                 -- Adresse du bâtiment
  contact TEXT NOT NULL,                 -- Nom du propriétaire  
  type TEXT NOT NULL,                    -- Type: Résidentiel, Commercial...
  geom TEXT NOT NULL                     -- Coordonnées GPS au format GeoJSON
);
```

### Opérations CRUD expliquées

#### CREATE - Ajouter une construction
```dart
Future<int> create(Construction construction) async {
  final db = await instance.database;
  return await db.insert('constructions', construction.toMap());
}
```
**Ce qui se passe** : L'objet Construction est converti en Map, puis inséré en base avec un nouvel ID automatique.

#### READ - Lire les constructions  
```dart
Future<List<Construction>> readAllConstructions() async {
  final db = await instance.database;
  final result = await db.query('constructions');
  return result.map((json) => Construction.fromMap(json)).toList();
}
```
**Ce qui se passe** : On récupère toutes les lignes, puis on les convertit en objets Construction.

#### UPDATE - Modifier une construction
```dart
Future<int> update(Construction construction) async {
  final db = await instance.database;
  return await db.update('constructions', construction.toMap(), where: 'id = ?', whereArgs: [construction.id]);
}
```
**Ce qui se passe** : On trouve la ligne avec l'ID correspondant et on la remplace.

#### DELETE - Supprimer une construction
```dart
Future<int> delete(int id) async {
  final db = await instance.database;
  return await db.delete('constructions', where: 'id = ?', whereArgs: [id]);
}
```
**Ce qui se passe** : On supprime la ligne qui a cet ID.

### Format GeoJSON expliqué

Au lieu de stocker les points comme "33.5,-7.6;33.6,-7.5;33.5,-7.5", on utilise le **format GeoJSON standard** :

```json
{
  "type": "Polygon",
  "coordinates": [
    [
      [-7.6, 33.5],    // [longitude, latitude] - Point 1
      [-7.5, 33.6],    // [longitude, latitude] - Point 2  
      [-7.5, 33.5],    // [longitude, latitude] - Point 3
      [-7.6, 33.5]     // [longitude, latitude] - Retour au point 1 (polygone fermé)
    ]
  ]
}
```

**Avantages** :
- Format **universel** compris par tous les logiciels SIG
- **Structure claire** et organisée
- **Extensible** (on peut ajouter des propriétés)
- **Validable** (on peut vérifier si c'est correct)

---

## ❓ Questions fréquentes de soutenance

### Questions sur l'architecture

**Q: Pourquoi avoir séparé le code en plusieurs dossiers ?**  
**R:** Pour appliquer le principe de **séparation des responsabilités**. Chaque dossier a un rôle précis :
- `screens/` → Interface utilisateur
- `models/` → Structure des données  
- `db/` → Base de données
- `utils/` → Calculs réutilisables

C'est plus **maintenable**, **lisible**, et **extensible**.

**Q: Qu'est-ce que le pattern MVC et l'utilisez-vous ?**  
**R:** MVC = **Model-View-Controller**. Notre app s'en inspire :
- **Model** → `models/construction.dart` + `db/database_helper.dart`
- **View** → `screens/*` (interface utilisateur)
- **Controller** → Logique dans les State classes + `utils/*`

### Questions sur Flutter

**Q: Différence entre StatefulWidget et StatelessWidget ?**  
**R:**
- **StatelessWidget** : Ne change jamais (comme du texte fixe)
- **StatefulWidget** : Peut changer d'apparence (comme notre liste qui se met à jour)

Notre app utilise StatefulWidget car on affiche des données qui changent.

**Q: Comment fonctionne setState() ?**  
**R:** `setState()` dit à Flutter "j'ai modifié des données, redessine l'écran". C'est comme appuyer sur F5 pour actualiser, mais automatique.

**Q: Pourquoi utiliser Navigator ?**  
**R:** Navigator gère la **pile d'écrans**. Comme un historique de navigation :
- `push()` → Ajouter un écran au-dessus
- `pop()` → Revenir à l'écran précédent  
- `pushReplacement()` → Remplacer l'écran actuel

### Questions sur la base de données

**Q: Pourquoi SQLite plutôt qu'un serveur en ligne ?**  
**R:** 
- ✅ **Fonctionne hors ligne** (terrain sans réseau)
- ✅ **Plus rapide** (pas d'attente réseau)
- ✅ **Données sécurisées** sur l'appareil
- ✅ **Moins complexe** à gérer

**Q: Comment gérer la synchronisation avec un serveur ?**  
**R:** On peut ajouter plus tard :
1. Un champ `synced` (true/false) dans la table
2. Une fonction qui envoie les données non synchronisées quand internet est disponible
3. Un service en arrière-plan pour la synchronisation automatique

**Q: Que se passe-t-il si la base de données est corrompue ?**  
**R:** On gère ça avec des try-catch et des vérifications :
```dart
try {
  final data = await database.query(...);
} catch (e) {
  // Recréer la base ou afficher une erreur
}
```

### Questions sur la géolocalisation

**Q: Comment fonctionne le GPS dans votre app ?**  
**R:** On utilise le package `geolocator` :
1. Demander la permission utilisateur
2. Vérifier que le GPS est activé  
3. Obtenir les coordonnées latitude/longitude
4. Les convertir en points sur la carte

**Q: Comment gérez-vous les erreurs GPS ?**  
**R:** Plusieurs vérifications :
- Permission refusée → Dialogue explicatif
- GPS désactivé → Redirection vers paramètres
- Pas de signal → Position par défaut + message

**Q: Qu'est-ce que GeoJSON et pourquoi l'utiliser ?**  
**R:** GeoJSON est un **format standard** pour stocker des formes géographiques. Avantages :
- **Interopérable** avec d'autres logiciels SIG
- **Structure claire** et **validable**
- Supporté par tous les outils cartographiques

### Questions sur l'interface

**Q: Pourquoi utiliser flutter_map plutôt que Google Maps ?**  
**R:**
- ✅ **Gratuit** (pas de clé API payante)  
- ✅ **Open source** 
- ✅ **Fonctionne hors ligne** avec des tuiles téléchargées
- ✅ **Plus de contrôle** sur l'affichage

**Q: Comment gérez-vous la réactivité sur différentes tailles d'écran ?**  
**R:** Avec des widgets adaptatifs :
- `MediaQuery` pour connaître la taille d'écran
- `Expanded` et `Flexible` pour s'adapter automatiquement
- `SingleChildScrollView` pour éviter les débordements

### Questions sur les performances

**Q: Comment optimisez-vous l'affichage de nombreux polygones ?**  
**R:** Plusieurs techniques possibles :
- **Clustering** : Grouper les polygones proches
- **Lazy loading** : Charger seulement les polygones visibles
- **Simplification** : Réduire le nombre de points selon le zoom

**Q: Comment gérer la mémoire avec de gros volumes de données ?**  
**R:**
- Utiliser `ListView.builder` (création à la demande)
- Limiter les requêtes avec `LIMIT` en SQL
- Libérer les ressources dans `dispose()`

---

## 📊 Schémas et diagrammes

### Diagramme de navigation

```
    [Démarrage]
         │
         ▼
   [LoginScreen]
    │         │
    │ admin/1234
    ▼         │
[MapScreen] ◄─┘
    │    │
    │    │ [Bouton Liste]
    │    ▼
    │  [ConstructionListScreen]
    │    │           │
    │    │ [Clic]    │ [Retour]
    │    ▼           │
    │  [MapScreen]◄──┘
    │  (centré)
    │
    │ [Bouton +]
    ▼
[AddConstructionScreen]
    │
    │ [Enregistrer]
    ▼
[MapScreen]
(avec nouvelle construction)
```

### Diagramme de la base de données

```
┌─────────────────────┐
│    constructions    │
├─────────────────────┤
│ id (PK)            │ INTEGER AUTO_INCREMENT
│ adresse            │ TEXT NOT NULL
│ contact            │ TEXT NOT NULL  
│ type               │ TEXT NOT NULL
│ geom               │ TEXT NOT NULL (GeoJSON)
└─────────────────────┘
```

### Diagramme de classes principales

```
┌─────────────────────┐
│    Construction     │
├─────────────────────┤
│ - id: int?          │
│ - adresse: String   │
│ - contact: String   │  
│ - type: String      │
│ - geom: String      │
├─────────────────────┤
│ + toMap()          │
│ + fromMap()        │
│ + getCentroid()    │
│ + getPolygonPoints()│
│ + isValidPolygon() │
└─────────────────────┘
         │
         │ utilise
         ▼
┌─────────────────────┐
│   DatabaseHelper    │
├─────────────────────┤
│ - _database         │
├─────────────────────┤
│ + create()         │
│ + readAll()        │
│ + update()         │
│ + delete()         │
│ + search()         │
└─────────────────────┘
```

### Flux de données - Ajout de construction

```
[Utilisateur dessine] 
         │
         ▼
[Capture points GPS]
         │
         ▼  
[Validation polygone] ← GeoJsonHelper.isValidPolygon()
         │
         ▼
[Conversion GeoJSON] ← GeoJsonHelper.pointsToGeoJson()
         │
         ▼
[Création objet Construction]
         │
         ▼
[Sauvegarde SQLite] ← DatabaseHelper.create()
         │
         ▼
[Mise à jour interface] ← setState()
         │
         ▼
[Affichage sur carte]
```

---

## 🚀 Installation et lancement

### Prérequis

- **Flutter SDK** installé
- **IDE** (VS Code ou Android Studio)
- **Device** : Windows (Mode développeur activé), Android, ou iOS

### Installation

1. **Cloner le projet**
   ```bash
   git clone [url-du-projet]
   cd Sig-mobile
   ```

2. **Récupérer les dépendances**
   ```bash
   flutter pub get
   ```

3. **Lancer sur Windows**
   ```bash
   flutter run -d windows
   ```

### Identifiants de connexion

| Champ | Valeur |
|-------|--------|
| **Identifiant** | admin |
| **Mot de passe** | 1234 |

### Test de l'application

1. **Se connecter** avec admin/1234
2. **Cliquer sur +** pour ajouter une construction
3. **Dessiner un polygone** (3 points minimum)
4. **Valider** le polygone
5. **Remplir le formulaire**
6. **Enregistrer**
7. **Voir le résultat** sur la carte
8. **Tester la liste** et la recherche

---

## 🎯 Points forts à présenter

### 1. Architecture claire
- Code bien organisé et maintenable
- Séparation des responsabilités
- Réutilisabilité des composants

### 2. Fonctionnalités complètes
- Toutes les exigences du cahier des charges respectées
- Interface intuitive et ergonomique
- Gestion robuste des erreurs

### 3. Technologies adaptées  
- Flutter pour le multi-plateforme
- SQLite pour le fonctionnement hors ligne
- Packages éprouvés et maintenus

### 4. Expérience utilisateur
- Navigation fluide entre les écrans
- Feedback visuel (loaders, messages)
- Validation des saisies utilisateur

### 5. Extensibilité
- Architecture prête pour de nouvelles fonctionnalités
- Code commenté et documenté
- Patterns de développement respectés

---

**💡 Conseil pour la soutenance** : Préparez une **démonstration** en live ! Rien ne vaut de montrer l'application qui fonctionne réellement avec des données que vous avez saisies vous-même.

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
"# Sig-mobile" 
