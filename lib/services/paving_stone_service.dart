import 'package:stock_pilot/models/paving_stone.dart';

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
}
