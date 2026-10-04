import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Abre la única base de datos del Drive en el almacenamiento privado de la
/// aplicación. Tener la ubicación centralizada simplifica el respaldo futuro.
class DriveBaseDatos {
  DriveBaseDatos._();

  static final DriveBaseDatos instancia = DriveBaseDatos._();

  Database? _baseDatos;

  Future<Database> get baseDatos async {
    final existente = _baseDatos;
    if (existente != null) return existente;

    final directorio = await getApplicationSupportDirectory();
    final carpetaDrive = Directory(
      '${directorio.path}${Platform.pathSeparator}killua_drive',
    );
    await carpetaDrive.create(recursive: true);

    final baseDatos = await openDatabase(
      '${carpetaDrive.path}${Platform.pathSeparator}drive.sqlite',
      version: 6,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Helper to safely add a column only if it doesn't already exist
        Future<void> addColumnIfMissing(
          Database db,
          String column,
          String definition,
        ) async {
          final cols = await db.rawQuery('PRAGMA table_info(elementos_drive)');
          final exists = cols.any((c) => c['name'] == column);
          if (!exists) {
            await db.execute(
              'ALTER TABLE elementos_drive ADD COLUMN $column $definition',
            );
          }
        }

        if (oldVersion < 2) {
          await addColumnIfMissing(
            db,
            'protegida',
            'INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await addColumnIfMissing(
            db,
            'favorita',
            'INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 4) {
          await addColumnIfMissing(db, 'lenguaje', 'TEXT');
          await addColumnIfMissing(db, 'orden', 'INTEGER NOT NULL DEFAULT 0');
          await addColumnIfMissing(
            db,
            'prioridad',
            'INTEGER NOT NULL DEFAULT 0',
          );

          await db.execute('''
            CREATE TABLE IF NOT EXISTS eventos_calendario (
              id TEXT PRIMARY KEY NOT NULL,
              fecha INTEGER NOT NULL,
              titulo TEXT NOT NULL,
              descripcion TEXT,
              color INTEGER,
              completado INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('PRAGMA defer_foreign_keys = ON');
          await db.execute('''
            CREATE TABLE elementos_drive_nuevo (
              id TEXT PRIMARY KEY NOT NULL,
              padre_id TEXT REFERENCES elementos_drive_nuevo(id) ON DELETE CASCADE,
              tipo TEXT NOT NULL CHECK(tipo IN ('carpeta', 'nota', 'documento', 'codigo')),
              nombre TEXT NOT NULL,
              contenido TEXT,
              ruta_relativa TEXT,
              mime TEXT,
              tamano INTEGER,
              creado INTEGER NOT NULL,
              modificado INTEGER NOT NULL,
              protegida INTEGER NOT NULL DEFAULT 0,
              favorita INTEGER NOT NULL DEFAULT 0,
              lenguaje TEXT,
              orden INTEGER NOT NULL DEFAULT 0,
              prioridad INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            INSERT INTO elementos_drive_nuevo
            SELECT id, padre_id, tipo, nombre, contenido, ruta_relativa, mime,
              tamano, creado, modificado, protegida, favorita, lenguaje, orden,
              prioridad
            FROM elementos_drive
          ''');
          await db.execute('DROP TABLE elementos_drive');
          await db.execute(
            'ALTER TABLE elementos_drive_nuevo RENAME TO elementos_drive',
          );
          await db.execute('''
            CREATE INDEX indice_elementos_drive_padre
            ON elementos_drive(padre_id, tipo, nombre COLLATE NOCASE)
          ''');
        }
      },
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE elementos_drive (
            id TEXT PRIMARY KEY NOT NULL,
            padre_id TEXT REFERENCES elementos_drive(id) ON DELETE CASCADE,
            tipo TEXT NOT NULL CHECK(tipo IN ('carpeta', 'nota', 'documento', 'codigo')),
            nombre TEXT NOT NULL,
            contenido TEXT,
            ruta_relativa TEXT,
            mime TEXT,
            tamano INTEGER,
            creado INTEGER NOT NULL,
            modificado INTEGER NOT NULL,
            protegida INTEGER NOT NULL DEFAULT 0,
            favorita INTEGER NOT NULL DEFAULT 0,
            lenguaje TEXT,
            orden INTEGER NOT NULL DEFAULT 0,
            prioridad INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE INDEX indice_elementos_drive_padre
          ON elementos_drive(padre_id, tipo, nombre COLLATE NOCASE)
        ''');
        await db.execute('''
          CREATE TABLE eventos_calendario (
            id TEXT PRIMARY KEY NOT NULL,
            fecha INTEGER NOT NULL,
            titulo TEXT NOT NULL,
            descripcion TEXT,
            color INTEGER,
            completado INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    _baseDatos = baseDatos;
    return baseDatos;
  }

  /// Carpeta raíz para los archivos importados. No se guarda la ruta absoluta
  /// en la base de datos; cada documento sólo conserva su ruta relativa.
  Future<Directory> get carpetaDocumentos async {
    final directorio = await getApplicationSupportDirectory();
    final carpeta = Directory(
      '${directorio.path}${Platform.pathSeparator}killua_drive'
      '${Platform.pathSeparator}documentos',
    );
    await carpeta.create(recursive: true);
    return carpeta;
  }
}
