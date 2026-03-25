import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/paving_stone.dart';
import 'package:stock_pilot/services/paving_stone_service.dart';

void main() {
  // Stone: 200x100mm → 0.02 m²/piece, 10 pcs/layer → 0.2 m²/layer, 6 layers → 1.2 m²/pallet
  final stone = PavingStone(
    name: 'Test',
    lengthMm: 200,
    widthMm: 100,
    thicknessMm: 60,
    piecesPerLayer: 10,
    layersPerPallet: 6,
  );

  group('PavingStoneService.calculate()', () {
    test('exact m2 — no rounding needed', () {
      // 2 full layers = 0.4 m² exactly
      final result = PavingStoneService.calculate(0.4, stone);
      expect(result.totalPieces, equals(20));
      expect(result.fullPallets, equals(0));
      expect(result.remainingLayers, equals(2));
      expect(result.partialPieces, equals(20));
      expect(result.actualM2, closeTo(0.4, 0.0001));
    });

    test('rounds up to nearest layer', () {
      // 0.21 m² → needs ceil(0.21/0.2)=2 layers → 20 pieces
      final result = PavingStoneService.calculate(0.21, stone);
      expect(result.totalPieces, equals(20));
      expect(result.remainingLayers, equals(2));
    });

    test('full pallet only — no partial', () {
      // 1.2 m² exactly = 1 full pallet, 0 remaining
      final result = PavingStoneService.calculate(1.2, stone);
      expect(result.totalPieces, equals(60));
      expect(result.fullPallets, equals(1));
      expect(result.remainingLayers, equals(0));
      expect(result.partialPieces, equals(0));
    });

    test('partial pallet decomposition (1 pallet + 1 remaining layer)', () {
      // 1.3 m² → ceil(1.3/0.2)=7 layers → fullPallets=1, remainingLayers=1, partialPieces=10
      final result = PavingStoneService.calculate(1.3, stone);
      expect(result.fullPallets, equals(1));
      expect(result.remainingLayers, equals(1));
      expect(result.partialPieces, equals(10));
    });

    test('very small: less than one layer rounds up to 1 layer', () {
      final result = PavingStoneService.calculate(0.01, stone);
      expect(result.totalPieces, equals(10));
      expect(result.fullPallets, equals(0));
      expect(result.remainingLayers, equals(1));
    });

    test('asserts on zero or negative m2', () {
      expect(() => PavingStoneService.calculate(0, stone), throwsA(isA<AssertionError>()));
      expect(() => PavingStoneService.calculate(-1, stone), throwsA(isA<AssertionError>()));
    });
  });
}
