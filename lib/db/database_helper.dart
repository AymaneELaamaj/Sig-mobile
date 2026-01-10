import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/construction.dart';
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

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // Création de la table (Appelé une seule fois à la création du fichier)
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
    print("Table 'constructions' créée avec succès");
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
}
