import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/construction.dart';
import '../models/tour.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  // Singleton : Une seule instance de la classe
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Getter pour récupérer la base de données
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sig_mobile.db');
    return _database!;
  }

  // Initialisation de la base
  Future<Database> _initDB(String filePath) async {
    // 1. Sur le Web, SQLite n'est pas supporté nativement
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite n\'est pas supporté sur le Web. '
        'Utilisez une base de données compatible Web comme IndexedDB.',
      );
    }

    // 2. Configuration pour Windows/Linux (Desktop)
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // 3. Configuration standard pour Android/iOS (Mobile) et Desktop
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 2, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Création des tables
  Future _createDB(Database db, int version) async {
    // Table constructions
    await db.execute('''
    CREATE TABLE constructions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      adresse TEXT NOT NULL,
      contact TEXT NOT NULL,
      type TEXT NOT NULL,
      geom TEXT NOT NULL
    )
    ''');
    
    // Table tours (tournées)
    await db.execute('''
    CREATE TABLE tours (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL,
      started_at TEXT,
      completed_at TEXT
    )
    ''');
    
    // Table tour_stops (arrêts de tournée)
    await db.execute('''
    CREATE TABLE tour_stops (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tour_id INTEGER NOT NULL,
      construction_id INTEGER NOT NULL,
      adresse TEXT NOT NULL,
      type TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      status INTEGER DEFAULT 0,
      visited_at TEXT,
      notes TEXT,
      order_index INTEGER DEFAULT 0,
      FOREIGN KEY (tour_id) REFERENCES tours (id) ON DELETE CASCADE,
      FOREIGN KEY (construction_id) REFERENCES constructions (id)
    )
    ''');
    
    print("Tables créées avec succès");
  }

  // Migration de la base de données
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Ajouter les tables de tournées
      await db.execute('''
      CREATE TABLE IF NOT EXISTS tours (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT
      )
      ''');
      
      await db.execute('''
      CREATE TABLE IF NOT EXISTS tour_stops (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tour_id INTEGER NOT NULL,
        construction_id INTEGER NOT NULL,
        adresse TEXT NOT NULL,
        type TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        status INTEGER DEFAULT 0,
        visited_at TEXT,
        notes TEXT,
        order_index INTEGER DEFAULT 0,
        FOREIGN KEY (tour_id) REFERENCES tours (id) ON DELETE CASCADE,
        FOREIGN KEY (construction_id) REFERENCES constructions (id)
      )
      ''');
      
      print("Migration vers version 2 effectuée");
    }
  }

  // --- CRUD OPÉRATIONS ---

  // Sauvegarder une construction
  Future<int> create(Construction construction) async {
    final db = await instance.database;
    return await db.insert('constructions', construction.toMap());
  }

  // Lire toutes les constructions
  Future<List<Construction>> readAllConstructions() async {
    final db = await instance.database;
    final result = await db.query('constructions');

    return result.map((json) => Construction.fromMap(json)).toList();
  }

  // Lire une construction par ID
  Future<Construction?> readConstruction(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'constructions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Construction.fromMap(maps.first);
    }
    return null;
  }

  // Mettre à jour une construction
  Future<int> update(Construction construction) async {
    final db = await instance.database;
    return await db.update(
      'constructions',
      construction.toMap(),
      where: 'id = ?',
      whereArgs: [construction.id],
    );
  }

  // Supprimer une construction
  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'constructions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Supprimer toutes les constructions
  Future<int> deleteAll() async {
    final db = await instance.database;
    return await db.delete('constructions');
  }

  // Rechercher des constructions par type
  Future<List<Construction>> searchByType(String type) async {
    final db = await instance.database;
    final result = await db.query(
      'constructions',
      where: 'type = ?',
      whereArgs: [type],
    );

    return result.map((json) => Construction.fromMap(json)).toList();
  }

  // Rechercher des constructions par mot-clé (adresse ou contact)
  Future<List<Construction>> search(String keyword) async {
    final db = await instance.database;
    final result = await db.query(
      'constructions',
      where: 'adresse LIKE ? OR contact LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
    );

    return result.map((json) => Construction.fromMap(json)).toList();
  }

  // Compter le nombre de constructions
  Future<int> count() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM constructions');
    return result.first['count'] as int;
  }

  // Fermer la base
  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // ============================================
  // OPÉRATIONS TOURNÉES (Tours)
  // ============================================

  /// Créer une nouvelle tournée
  Future<int> createTour(Tour tour) async {
    final db = await instance.database;
    return await db.insert('tours', tour.toMap());
  }

  /// Lire toutes les tournées
  Future<List<Tour>> readAllTours() async {
    final db = await instance.database;
    final result = await db.query('tours', orderBy: 'created_at DESC');
    
    List<Tour> tours = [];
    for (var tourMap in result) {
      final stops = await readTourStops(tourMap['id'] as int);
      tours.add(Tour.fromMap(tourMap, stops: stops));
    }
    return tours;
  }

  /// Lire une tournée par ID avec ses stops
  Future<Tour?> readTour(int id) async {
    final db = await instance.database;
    final maps = await db.query('tours', where: 'id = ?', whereArgs: [id]);
    
    if (maps.isNotEmpty) {
      final stops = await readTourStops(id);
      return Tour.fromMap(maps.first, stops: stops);
    }
    return null;
  }

  /// Mettre à jour une tournée
  Future<int> updateTour(Tour tour) async {
    final db = await instance.database;
    return await db.update(
      'tours',
      tour.toMap(),
      where: 'id = ?',
      whereArgs: [tour.id],
    );
  }

  /// Supprimer une tournée
  Future<int> deleteTour(int id) async {
    final db = await instance.database;
    // Les stops seront supprimés automatiquement (CASCADE)
    return await db.delete('tours', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================
  // OPÉRATIONS ARRÊTS DE TOURNÉE (TourStops)
  // ============================================

  /// Ajouter un stop à une tournée
  Future<int> addTourStop(int tourId, TourStop stop) async {
    final db = await instance.database;
    final map = stop.toMap();
    map['tour_id'] = tourId;
    return await db.insert('tour_stops', map);
  }

  /// Ajouter plusieurs stops à une tournée
  Future<void> addTourStops(int tourId, List<TourStop> stops) async {
    final db = await instance.database;
    final batch = db.batch();
    
    for (var stop in stops) {
      final map = stop.toMap();
      map['tour_id'] = tourId;
      batch.insert('tour_stops', map);
    }
    
    await batch.commit(noResult: true);
  }

  /// Lire les stops d'une tournée
  Future<List<TourStop>> readTourStops(int tourId) async {
    final db = await instance.database;
    final result = await db.query(
      'tour_stops',
      where: 'tour_id = ?',
      whereArgs: [tourId],
      orderBy: 'order_index ASC',
    );
    
    return result.map((json) => TourStop.fromMap(json)).toList();
  }

  /// Mettre à jour un stop
  Future<int> updateTourStop(int stopId, TourStop stop) async {
    final db = await instance.database;
    return await db.update(
      'tour_stops',
      stop.toMap(),
      where: 'id = ?',
      whereArgs: [stopId],
    );
  }

  /// Mettre à jour le statut d'un stop
  Future<int> updateTourStopStatus(
    int tourId, 
    int constructionId, 
    VisitStatus status,
    {String? notes}
  ) async {
    final db = await instance.database;
    
    Map<String, dynamic> values = {
      'status': status.index,
    };
    
    if (status == VisitStatus.visited) {
      values['visited_at'] = DateTime.now().toIso8601String();
    }
    
    if (notes != null) {
      values['notes'] = notes;
    }
    
    return await db.update(
      'tour_stops',
      values,
      where: 'tour_id = ? AND construction_id = ?',
      whereArgs: [tourId, constructionId],
    );
  }

  /// Mettre à jour l'ordre des stops
  Future<void> updateTourStopsOrder(int tourId, List<int> constructionIds) async {
    final db = await instance.database;
    final batch = db.batch();
    
    for (int i = 0; i < constructionIds.length; i++) {
      batch.update(
        'tour_stops',
        {'order_index': i},
        where: 'tour_id = ? AND construction_id = ?',
        whereArgs: [tourId, constructionIds[i]],
      );
    }
    
    await batch.commit(noResult: true);
  }

  /// Supprimer un stop d'une tournée
  Future<int> removeTourStop(int tourId, int constructionId) async {
    final db = await instance.database;
    return await db.delete(
      'tour_stops',
      where: 'tour_id = ? AND construction_id = ?',
      whereArgs: [tourId, constructionId],
    );
  }

  /// Marquer une tournée comme démarrée
  Future<int> startTour(int tourId) async {
    final db = await instance.database;
    return await db.update(
      'tours',
      {'started_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [tourId],
    );
  }

  /// Marquer une tournée comme terminée
  Future<int> completeTour(int tourId) async {
    final db = await instance.database;
    return await db.update(
      'tours',
      {'completed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [tourId],
    );
  }
}
