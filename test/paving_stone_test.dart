import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pilot/models/paving_stone.dart';

void main() {
  group('PavingStone', () {
    // Stone: 200mm x 100mm, 10 pcs/layer, 6 layers/pallet
    final stone = PavingStone(
      name: 'Dlažba 20x10x6',
      lengthMm: 200,
      widthMm: 100,
      thicknessMm: 60,
      piecesPerLayer: 10,
      layersPerPallet: 6,
    );

    test('m2PerPiece is correct', () {
      expect(stone.m2PerPiece, closeTo(0.02, 0.0001));
    });

    test('m2PerLayer is correct', () {
      expect(stone.m2PerLayer, closeTo(0.2, 0.0001));
    });

    test('m2PerPallet is correct', () {
      expect(stone.m2PerPallet, closeTo(1.2, 0.0001));
    });

    test('piecesPerPallet is correct', () {
      expect(stone.piecesPerPallet, equals(60));
    });

    test('toMap and fromMap round-trip', () {
      final map = stone.toMap();
      final restored = PavingStone.fromMap(map);
      expect(restored.name, equals(stone.name));
      expect(restored.lengthMm, equals(stone.lengthMm));
      expect(restored.piecesPerLayer, equals(stone.piecesPerLayer));
      expect(restored.layersPerPallet, equals(stone.layersPerPallet));
    });

    test('copyWith overrides specified fields only', () {
      final updated = stone.copyWith(name: 'Updated');
      expect(updated.name, equals('Updated'));
      expect(updated.lengthMm, equals(stone.lengthMm));
    });
  });
}
