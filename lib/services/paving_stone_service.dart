import 'package:stock_pilot/models/paving_stone.dart';
import 'package:stock_pilot/services/Database/database_service.dart';

class PavingStoneCalculation {
  final int totalPieces;
  final int fullPallets;
  final int remainingLayers;
  final int partialPieces;
  final double actualM2;

  const PavingStoneCalculation({
    required this.totalPieces,
    required this.fullPallets,
    required this.remainingLayers,
    required this.partialPieces,
    required this.actualM2,
  });
}

class PavingStoneService {
  /// Pure conversion: requestedM2 → pieces, rounded UP to nearest full layer.
  /// Layer is always the atomic unit. Pallet is a grouping of layers.
  static PavingStoneCalculation calculate(double requestedM2, PavingStone stone) {
    assert(requestedM2 > 0, 'requestedM2 must be positive');
    final totalLayers = (requestedM2 / stone.m2PerLayer).ceil();
    final totalPieces = totalLayers * stone.piecesPerLayer;
    final fullPallets = totalLayers ~/ stone.layersPerPallet;
    final remainingLayers = totalLayers % stone.layersPerPallet;
    final partialPieces = remainingLayers * stone.piecesPerLayer;
    final actualM2 = totalPieces * stone.m2PerPiece;

    return PavingStoneCalculation(
      totalPieces: totalPieces,
      fullPallets: fullPallets,
      remainingLayers: remainingLayers,
      partialPieces: partialPieces,
      actualM2: actualM2,
    );
  }

  final DatabaseService _db = DatabaseService();

  Future<List<PavingStone>> getPavingStones(String? userId) async {
    final db = await _db.database;
    final maps = await db.query(
      'paving_stones',
      where: userId != null ? 'user_id = ?' : null,
      whereArgs: userId != null ? [userId] : null,
      orderBy: 'name ASC',
    );
    return maps.map(PavingStone.fromMap).toList();
  }

  Future<PavingStone?> getPavingStoneById(int id) async {
    final db = await _db.database;
    final maps = await db.query('paving_stones', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return PavingStone.fromMap(maps.first);
  }

  Future<int> insertPavingStone(PavingStone stone) async {
    final db = await _db.database;
    final map = Map<String, Object?>.from(stone.toMap())..remove('id');
    map['created_at'] ??= DateTime.now().toIso8601String();
    return db.insert('paving_stones', map);
  }

  Future<void> updatePavingStone(PavingStone stone) async {
    final db = await _db.database;
    await db.update(
      'paving_stones',
      stone.toMap(),
      where: 'id = ?',
      whereArgs: [stone.id],
    );
  }

  Future<void> deletePavingStone(int id) async {
    final db = await _db.database;
    await db.delete('paving_stones', where: 'id = ?', whereArgs: [id]);
  }
}
