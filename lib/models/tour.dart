import 'package:latlong2/latlong.dart';

/// Statut d'une visite
enum VisitStatus {
  pending,    // À visiter
  visited,    // Visité
  toReview,   // À revoir
  skipped,    // Passé
}

/// Extension pour obtenir les propriétés d'affichage du statut
extension VisitStatusExtension on VisitStatus {
  String get label {
    switch (this) {
      case VisitStatus.pending:
        return 'À visiter';
      case VisitStatus.visited:
        return 'Visité';
      case VisitStatus.toReview:
        return 'À revoir';
      case VisitStatus.skipped:
        return 'Passé';
    }
  }

  String get icon {
    switch (this) {
      case VisitStatus.pending:
        return '⏳';
      case VisitStatus.visited:
        return '✅';
      case VisitStatus.toReview:
        return '🔄';
      case VisitStatus.skipped:
        return '⏭️';
    }
  }
}

/// Représente un point de visite dans une tournée
class TourStop {
  final int constructionId;
  final String adresse;
  final String type;
  final LatLng position;
  VisitStatus status;
  DateTime? visitedAt;
  String? notes;
  int orderIndex;

  TourStop({
    required this.constructionId,
    required this.adresse,
    required this.type,
    required this.position,
    this.status = VisitStatus.pending,
    this.visitedAt,
    this.notes,
    this.orderIndex = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'construction_id': constructionId,
      'adresse': adresse,
      'type': type,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'status': status.index,
      'visited_at': visitedAt?.toIso8601String(),
      'notes': notes,
      'order_index': orderIndex,
    };
  }

  factory TourStop.fromMap(Map<String, dynamic> map) {
    return TourStop(
      constructionId: map['construction_id'],
      adresse: map['adresse'],
      type: map['type'],
      position: LatLng(map['latitude'], map['longitude']),
      status: VisitStatus.values[map['status'] ?? 0],
      visitedAt: map['visited_at'] != null 
          ? DateTime.parse(map['visited_at']) 
          : null,
      notes: map['notes'],
      orderIndex: map['order_index'] ?? 0,
    );
  }

  TourStop copyWith({
    int? constructionId,
    String? adresse,
    String? type,
    LatLng? position,
    VisitStatus? status,
    DateTime? visitedAt,
    String? notes,
    int? orderIndex,
  }) {
    return TourStop(
      constructionId: constructionId ?? this.constructionId,
      adresse: adresse ?? this.adresse,
      type: type ?? this.type,
      position: position ?? this.position,
      status: status ?? this.status,
      visitedAt: visitedAt ?? this.visitedAt,
      notes: notes ?? this.notes,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}

/// Représente une tournée complète
class Tour {
  final int? id;
  final String name;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  List<TourStop> stops;
  
  Tour({
    this.id,
    required this.name,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.stops = const [],
  });

  /// Nombre de stops visités
  int get visitedCount => 
      stops.where((s) => s.status == VisitStatus.visited).length;

  /// Nombre de stops à revoir
  int get toReviewCount => 
      stops.where((s) => s.status == VisitStatus.toReview).length;

  /// Nombre de stops restants
  int get remainingCount => 
      stops.where((s) => s.status == VisitStatus.pending).length;

  /// Pourcentage de progression
  double get progress => 
      stops.isEmpty ? 0 : (visitedCount / stops.length) * 100;

  /// La tournée est-elle terminée ?
  bool get isCompleted => 
      stops.isNotEmpty && remainingCount == 0;

  /// Prochain stop à visiter
  TourStop? get nextStop {
    final pending = stops.where((s) => s.status == VisitStatus.pending).toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return pending.first;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory Tour.fromMap(Map<String, dynamic> map, {List<TourStop>? stops}) {
    return Tour(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
      startedAt: map['started_at'] != null 
          ? DateTime.parse(map['started_at']) 
          : null,
      completedAt: map['completed_at'] != null 
          ? DateTime.parse(map['completed_at']) 
          : null,
      stops: stops ?? [],
    );
  }
}

/// Résultat de calcul d'itinéraire entre deux points
class RouteSegment {
  final LatLng start;
  final LatLng end;
  final List<LatLng> polylinePoints;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteInstruction> instructions;

  RouteSegment({
    required this.start,
    required this.end,
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    this.instructions = const [],
  });

  /// Distance formatée (km ou m)
  String get distanceFormatted {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toInt()} m';
  }

  /// Durée formatée (min ou h)
  String get durationFormatted {
    final minutes = (durationSeconds / 60).round();
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}min';
    }
    return '$minutes min';
  }
}

/// Instruction de navigation
class RouteInstruction {
  final String text;
  final String type; // turn-left, turn-right, straight, arrive, etc.
  final double distanceMeters;
  final LatLng position;

  RouteInstruction({
    required this.text,
    required this.type,
    required this.distanceMeters,
    required this.position,
  });

  factory RouteInstruction.fromOSRM(Map<String, dynamic> step) {
    final maneuver = step['maneuver'] as Map<String, dynamic>;
    final location = maneuver['location'] as List;
    
    return RouteInstruction(
      text: step['name'] ?? '',
      type: maneuver['type'] ?? 'straight',
      distanceMeters: (step['distance'] as num).toDouble(),
      position: LatLng(location[1].toDouble(), location[0].toDouble()),
    );
  }
}
