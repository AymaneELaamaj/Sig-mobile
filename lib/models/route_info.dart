import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Mode de transport pour le calcul d'itinéraire
enum TravelMode {
  driving('driving', '🚗', 'Voiture'),
  walking('foot', '🚶', 'À pied'),
  cycling('bike', '🚴', 'Vélo');

  final String osrmProfile;
  final String emoji;
  final String label;

  const TravelMode(this.osrmProfile, this.emoji, this.label);
}

/// Information sur un itinéraire calculé
class RouteInfo {
  /// Points de la polyline de l'itinéraire
  final List<LatLng> polylinePoints;

  /// Distance totale en mètres
  final double distanceMeters;

  /// Durée estimée en secondes
  final double durationSeconds;

  /// Instructions de navigation
  final List<NavigationStep> instructions;

  /// Point de départ
  final LatLng origin;

  /// Point d'arrivée
  final LatLng destination;

  /// Mode de transport utilisé
  final TravelMode travelMode;

  RouteInfo({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.instructions,
    required this.origin,
    required this.destination,
    required this.travelMode,
  });

  /// Distance formatée (km ou m)
  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toInt()} m';
  }

  /// Durée formatée (h min ou min)
  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}min';
    }
    return '$minutes min';
  }

  /// Heure d'arrivée estimée
  String get estimatedArrival {
    final arrival = DateTime.now().add(Duration(seconds: durationSeconds.round()));
    return '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
  }
}

/// Instruction de navigation individuelle
class NavigationStep {
  /// Type de manœuvre (turn, continue, arrive, etc.)
  final String type;

  /// Modificateur (left, right, straight, etc.)
  final String? modifier;

  /// Nom de la route
  final String? roadName;

  /// Distance jusqu'à la prochaine instruction (mètres)
  final double distanceMeters;

  /// Durée jusqu'à la prochaine instruction (secondes)
  final double durationSeconds;

  /// Texte de l'instruction
  final String text;

  NavigationStep({
    required this.type,
    this.modifier,
    this.roadName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.text,
  });

  /// Créer depuis une réponse OSRM
  factory NavigationStep.fromOSRM(Map<String, dynamic> step) {
    final maneuver = step['maneuver'] ?? {};
    final name = step['name'] ?? '';
    
    return NavigationStep(
      type: maneuver['type'] ?? 'continue',
      modifier: maneuver['modifier'],
      roadName: name.isNotEmpty ? name : null,
      distanceMeters: (step['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (step['duration'] as num?)?.toDouble() ?? 0,
      text: _buildInstructionText(maneuver, name),
    );
  }

  /// Construire le texte d'instruction en français
  static String _buildInstructionText(Map<String, dynamic> maneuver, String name) {
    final type = maneuver['type'] ?? '';
    final modifier = maneuver['modifier'] ?? '';
    
    String action;
    switch (type) {
      case 'depart':
        action = 'Départ';
        break;
      case 'arrive':
        action = 'Vous êtes arrivé';
        break;
      case 'turn':
        switch (modifier) {
          case 'left':
            action = 'Tournez à gauche';
            break;
          case 'right':
            action = 'Tournez à droite';
            break;
          case 'sharp left':
            action = 'Tournez fortement à gauche';
            break;
          case 'sharp right':
            action = 'Tournez fortement à droite';
            break;
          case 'slight left':
            action = 'Tournez légèrement à gauche';
            break;
          case 'slight right':
            action = 'Tournez légèrement à droite';
            break;
          case 'straight':
            action = 'Continuez tout droit';
            break;
          case 'uturn':
            action = 'Faites demi-tour';
            break;
          default:
            action = 'Tournez';
        }
        break;
      case 'continue':
        action = 'Continuez';
        break;
      case 'merge':
        action = 'Rejoignez';
        break;
      case 'roundabout':
      case 'rotary':
        action = 'Au rond-point';
        break;
      case 'fork':
        action = modifier == 'left' ? 'Prenez la sortie de gauche' : 'Prenez la sortie de droite';
        break;
      case 'end of road':
        action = 'En fin de route';
        break;
      case 'new name':
        action = 'Continuez sur';
        break;
      default:
        action = 'Continuez';
    }

    if (name.isNotEmpty && type != 'arrive') {
      return '$action sur $name';
    }
    return action;
  }

  /// Obtenir l'icône de direction
  IconData get directionIcon {
    switch (type) {
      case 'depart':
        return Icons.trip_origin;
      case 'arrive':
        return Icons.location_on;
      case 'turn':
        switch (modifier) {
          case 'left':
          case 'sharp left':
          case 'slight left':
            return Icons.turn_left;
          case 'right':
          case 'sharp right':
          case 'slight right':
            return Icons.turn_right;
          case 'uturn':
            return Icons.u_turn_left;
          default:
            return Icons.straight;
        }
      case 'roundabout':
      case 'rotary':
        return Icons.roundabout_left;
      case 'merge':
        return Icons.merge;
      case 'fork':
        return modifier == 'left' ? Icons.fork_left : Icons.fork_right;
      default:
        return Icons.straight;
    }
  }

  /// Distance formatée
  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toInt()} m';
  }
}
