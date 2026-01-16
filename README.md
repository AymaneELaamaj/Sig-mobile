# 📱 SIG Mobile - Application de Relevé Cartographique

> **Projet académique 2025-2026** | Enseignant : **LOTF HAMZA**  
> **Technologies** : Flutter • SQLite • flutter_map

---

## 🎯 Objectif

Application mobile pour **agents d'agence urbaine** permettant de :
- 📍 Dessiner les contours des bâtiments sur une carte
- 📝 Enregistrer les informations (adresse, propriétaire, type)
- 💾 Stocker les données **hors ligne** (SQLite)
- 🗺️ Visualiser toutes les constructions sur la carte

---

## 🏗️ Architecture du Projet

```
lib/
├── main.dart              # Point d'entrée
├── db/
│   └── database_helper.dart    # CRUD SQLite
├── models/
│   └── construction.dart       # Modèle de données
├── screens/
│   ├── login_screen.dart       # Authentification
│   ├── map_screen.dart         # Carte principale
│   ├── add_construction_screen.dart   # Ajout construction
│   └── construction_list_screen.dart  # Liste & recherche
├── utils/
│   ├── geojson_helper.dart     # Conversion GeoJSON
│   └── map_helper.dart         # Calculs cartographiques
└── widgets/
    ├── map_controls_widget.dart      # Contrôles de carte
    ├── map_search_bar.dart           # Barre de recherche
    ├── collapsible_legend_widget.dart # Légende
    ├── construction_popup.dart       # Popup détails
    └── gps_indicator_widget.dart     # Indicateur GPS
```

---

## 📊 Base de Données

```sql
CREATE TABLE constructions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  adresse TEXT NOT NULL,
  contact TEXT NOT NULL,
  type TEXT NOT NULL,        -- Résidentiel, Commercial, Industriel, Public
  geom TEXT NOT NULL         -- Coordonnées GeoJSON
);
```

---

## 🔄 Flux de Navigation

```
LoginScreen (admin/1234)
       ↓
   MapScreen ←──────────────┐
    ↓      ↓                │
   [+]   [Liste]            │
    ↓      ↓                │
AddScreen  ListScreen ──────┘
    ↓
  Retour avec données
```

---

## 📦 Dépendances Principales

| Package | Version | Rôle |
|---------|---------|------|
| `flutter_map` | 6.2.1 | Carte OpenStreetMap |
| `sqflite` | 2.3.0 | Base de données locale |
| `geolocator` | 10.1.1 | Localisation GPS |
| `latlong2` | 0.9.0 | Calculs géographiques |

---

## 🚀 Lancement

```bash
# Installation des dépendances
flutter pub get

# Lancer sur Windows
flutter run -d windows

# Lancer sur Android
flutter run -d android
```

### 🔐 Identifiants
| Champ | Valeur |
|-------|--------|
| Identifiant | `admin` |
| Mot de passe | `1234` |

---

## 🎨 Fonctionnalités UI

### Écran Carte (`map_screen.dart`)
- Carte interactive avec polygones colorés par type
- Légende collapsible avec statistiques
- Barre de recherche avec filtres
- Contrôles de zoom et GPS
- Sélecteur de couches (Standard, Satellite, Terrain, Sombre)

### Écran Ajout (`add_construction_screen.dart`)
- Interface de dessin en 2 étapes (Dessiner → Informations)
- Stepper visuel de progression
- Validation du polygone (min. 3 points)
- Sélecteur de type avec couleurs
- Aperçu du polygone validé

### Écran Liste (`construction_list_screen.dart`)
- Header avec statistiques par type
- Recherche en temps réel
- Filtres par catégorie
- Cards modernes avec actions

---

## 🎓 Concepts Flutter Utilisés

| Concept | Utilisation |
|---------|-------------|
| `StatefulWidget` | Gestion d'état des écrans |
| `setState()` | Mise à jour de l'interface |
| `Navigator` | Navigation entre écrans |
| `Form` + `GlobalKey` | Validation formulaires |
| `async/await` | Opérations base de données |
| `AnimationController` | Animations (GPS, transitions) |

---

## ❓ Questions Soutenance

**Q: Pourquoi SQLite ?**  
→ Fonctionne hors ligne, rapide, intégré au téléphone

**Q: Pourquoi flutter_map ?**  
→ Gratuit (pas de clé API), open source, fonctionne offline

**Q: C'est quoi GeoJSON ?**  
→ Format standard pour stocker les coordonnées géographiques

**Q: Différence StatefulWidget / StatelessWidget ?**  
→ Stateful peut changer d'apparence, Stateless est fixe

---

## ✅ Points Forts

- ✅ Architecture claire et maintenable
- ✅ Interface Material Design 3 moderne
- ✅ Fonctionne 100% hors ligne
- ✅ Code documenté et commenté
- ✅ Multi-plateforme (Windows, Android, iOS)

---

**💡 Conseil** : Préparez une démonstration live avec des données réelles !
