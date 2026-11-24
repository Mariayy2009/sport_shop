import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../services/try_on/garment_scan.dart';
import '../database/app_database.dart';
import '../database/database_schema.dart';

/// Примерки, отсканированные продавцами: снимки вещи (PNG) и опорные
/// линии. Покупатель в живой примерке видит вещь, снятую на человеке.
abstract class TryOnScanRepository {
  Future<ScanRecord?> forProduct(int productId);

  /// Сохраняет снимки спереди и сзади (PNG) и привязывает к товару.
  Future<ScanRecord> save(
    int productId, {
    required Uint8List frontPng,
    required ScanAnchors front,
    Uint8List? backPng,
    ScanAnchors? back,
  });
}

class LocalTryOnScanRepository implements TryOnScanRepository {
  LocalTryOnScanRepository(this._appDatabase, {Future<Directory> Function()? root})
      : _root = root ?? getApplicationSupportDirectory;

  final AppDatabase _appDatabase;
  final Future<Directory> Function() _root;

  @override
  Future<ScanRecord?> forProduct(int productId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseSchema.products,
      columns: ['try_on_image', 'try_on_meta'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final ScanRecord? record = ScanRecord.decode(
      rows.first['try_on_image'] as String?,
      rows.first['try_on_meta'] as String?,
    );
    // Файл могли удалить вместе с данными приложения.
    if (record == null || !File(record.frontPath).existsSync()) return null;
    return record;
  }

  @override
  Future<ScanRecord> save(
    int productId, {
    required Uint8List frontPng,
    required ScanAnchors front,
    Uint8List? backPng,
    ScanAnchors? back,
  }) async {
    final Directory dir = Directory(p.join((await _root()).path, 'try_on_scans'));
    await dir.create(recursive: true);
    final int stamp = DateTime.now().millisecondsSinceEpoch;
    final File frontFile = File(p.join(dir.path, 'product_${productId}_${stamp}_front.png'));
    await frontFile.writeAsBytes(frontPng);
    String? backPath;
    if (backPng != null && back != null) {
      final File backFile = File(p.join(dir.path, 'product_${productId}_${stamp}_back.png'));
      await backFile.writeAsBytes(backPng);
      backPath = backFile.path;
    }
    final ScanRecord record = ScanRecord(
      frontPath: frontFile.path,
      front: front,
      backPath: backPath,
      back: backPath == null ? null : back,
    );
    final Database db = await _appDatabase.database;
    await db.update(
      DatabaseSchema.products,
      {'try_on_image': record.frontPath, 'try_on_meta': record.encodeMeta()},
      where: 'id = ?',
      whereArgs: [productId],
    );
    return record;
  }
}
