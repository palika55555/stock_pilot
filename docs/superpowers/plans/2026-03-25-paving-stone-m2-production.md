# Paving Stone m²-First Production Module — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add m²-first input for paving stone production batches, with automatic layer-based rounding, pallet decomposition, and a stone catalog.

**Architecture:** Extend existing SQLite + Provider stack in-place. New `PavingStone` model + `PavingStoneService` (CRUD + pure `calculate()`). DB migrates from version 39→40. Three existing files are modified; two new screens added.

**Tech Stack:** Flutter, sqflite (SQLite), Provider pattern, flutter_test

**Spec:** `docs/superpowers/specs/2026-03-25-paving-stone-m2-production-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| CREATE | `lib/models/paving_stone.dart` | PavingStone entity + computed getters |
| CREATE | `lib/services/paving_stone_service.dart` | CRUD + pure `calculate()` |
| CREATE | `lib/screens/paving_stone/paving_stone_list_screen.dart` | Stone catalog CRUD UI |
| CREATE | `test/paving_stone_test.dart` | Unit tests for model |
| CREATE | `test/paving_stone_service_test.dart` | Unit tests for calculate() |
| MODIFY | `lib/models/production_batch.dart` | +3 nullable fields, toMap/fromMap/copyWith |
| MODIFY | `lib/services/Database/database_service.dart` | DB version 40, migration, CRUD for paving_stones |
| MODIFY | `lib/screens/production/production_batch_form_screen.dart` | Auto-switch to m² when paving stone selected |
| MODIFY | `lib/screens/pallet/create_pallets_dialog.dart` | Paving stone branch: locked piecesPerPallet, partial pallet |

---

## Task 1: PavingStone Model

**Files:**
- Create: `lib/models/paving_stone.dart`
- Create: `test/paving_stone_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/paving_stone_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/paving_stone_test.dart
```
Expected: compile error — `paving_stone.dart` does not exist yet.

- [ ] **Step 3: Implement the model**

Create `lib/models/paving_stone.dart`:

```dart
class PavingStone {
  final int? id;
  final String name;
  final double lengthMm;
  final double widthMm;
  final double thicknessMm;
  final int piecesPerLayer;
  final int layersPerPallet;
  final String? userId;
  final String? createdAt;

  const PavingStone({
    this.id,
    required this.name,
    required this.lengthMm,
    required this.widthMm,
    required this.thicknessMm,
    required this.piecesPerLayer,
    required this.layersPerPallet,
    this.userId,
    this.createdAt,
  });

  double get m2PerPiece    => (lengthMm * widthMm) / 1000000;
  double get m2PerLayer    => piecesPerLayer * m2PerPiece;
  double get m2PerPallet   => layersPerPallet * m2PerLayer;
  int    get piecesPerPallet => piecesPerLayer * layersPerPallet;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'length_mm': lengthMm,
    'width_mm': widthMm,
    'thickness_mm': thicknessMm,
    'pieces_per_layer': piecesPerLayer,
    'layers_per_pallet': layersPerPallet,
    'user_id': userId,
    'created_at': createdAt,
  };

  static PavingStone fromMap(Map<String, Object?> map) => PavingStone(
    id: map['id'] as int?,
    name: map['name'] as String,
    lengthMm: (map['length_mm'] as num).toDouble(),
    widthMm: (map['width_mm'] as num).toDouble(),
    thicknessMm: (map['thickness_mm'] as num).toDouble(),
    piecesPerLayer: map['pieces_per_layer'] as int,
    layersPerPallet: map['layers_per_pallet'] as int,
    userId: map['user_id'] as String?,
    createdAt: map['created_at'] as String?,
  );

  PavingStone copyWith({
    int? id,
    String? name,
    double? lengthMm,
    double? widthMm,
    double? thicknessMm,
    int? piecesPerLayer,
    int? layersPerPallet,
    String? userId,
    String? createdAt,
  }) => PavingStone(
    id: id ?? this.id,
    name: name ?? this.name,
    lengthMm: lengthMm ?? this.lengthMm,
    widthMm: widthMm ?? this.widthMm,
    thicknessMm: thicknessMm ?? this.thicknessMm,
    piecesPerLayer: piecesPerLayer ?? this.piecesPerLayer,
    layersPerPallet: layersPerPallet ?? this.layersPerPallet,
    userId: userId ?? this.userId,
    createdAt: createdAt ?? this.createdAt,
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

```
flutter test test/paving_stone_test.dart
```
Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/paving_stone.dart test/paving_stone_test.dart
git commit -m "feat: add PavingStone model with m2 getters"
```

---

## Task 2: PavingStoneCalculation + calculate()

**Files:**
- Create: `lib/services/paving_stone_service.dart` (just the pure logic, CRUD added in Task 5)
- Create: `test/paving_stone_service_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/paving_stone_service_test.dart`:

```dart
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

    test('full pallet + partial pallet', () {
      // 12 m² → ceil(12/0.2)=60 layers → 10 full pallets (6 layers each) + 0 remaining
      // Actually 60 layers / 6 = 10 pallets exactly, 0 remaining
      final result = PavingStoneService.calculate(12.0, stone);
      expect(result.totalPieces, equals(600));
      expect(result.fullPallets, equals(10));
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
      expect(result.totalPieces, equals(10)); // 1 full layer
      expect(result.fullPallets, equals(0));
      expect(result.remainingLayers, equals(1));
    });

    test('asserts on zero or negative m2', () {
      expect(() => PavingStoneService.calculate(0, stone), throwsA(isA<AssertionError>()));
      expect(() => PavingStoneService.calculate(-1, stone), throwsA(isA<AssertionError>()));
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```
flutter test test/paving_stone_service_test.dart
```
Expected: compile error — service file does not exist yet.

- [ ] **Step 3: Create service with calculate() only (CRUD comes in Task 5)**

Create `lib/services/paving_stone_service.dart`:

```dart
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
    final totalLayers      = (requestedM2 / stone.m2PerLayer).ceil();
    final totalPieces      = totalLayers * stone.piecesPerLayer;
    final fullPallets      = totalLayers ~/ stone.layersPerPallet;
    final remainingLayers  = totalLayers % stone.layersPerPallet;
    final partialPieces    = remainingLayers * stone.piecesPerLayer;
    final actualM2         = totalPieces * stone.m2PerPiece;

    return PavingStoneCalculation(
      totalPieces: totalPieces,
      fullPallets: fullPallets,
      remainingLayers: remainingLayers,
      partialPieces: partialPieces,
      actualM2: actualM2,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```
flutter test test/paving_stone_service_test.dart
```
Expected: all 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/paving_stone_service.dart test/paving_stone_service_test.dart
git commit -m "feat: add PavingStoneService.calculate() with layer rounding"
```

---

## Task 3: Update ProductionBatch Model

**Files:**
- Modify: `lib/models/production_batch.dart`

- [ ] **Step 1: Add 3 nullable fields**

In `lib/models/production_batch.dart`, make the following changes:

Add fields after `revenueTotal`:
```dart
final int? pavingStoneId;
final double? requestedM2;
final double? actualStoredM2;
```

Add to constructor:
```dart
this.pavingStoneId,
this.requestedM2,
this.actualStoredM2,
```

Add to `toMap()`:
```dart
'paving_stone_id': pavingStoneId,
'requested_m2': requestedM2,
'actual_stored_m2': actualStoredM2,
```

Add to `fromMap()`:
```dart
pavingStoneId: map['paving_stone_id'] as int?,
requestedM2: (map['requested_m2'] as num?)?.toDouble(),
actualStoredM2: (map['actual_stored_m2'] as num?)?.toDouble(),
```

Add to `copyWith()` signature and body:
```dart
int? pavingStoneId,
double? requestedM2,
double? actualStoredM2,
// ...
pavingStoneId: pavingStoneId ?? this.pavingStoneId,
requestedM2: requestedM2 ?? this.requestedM2,
actualStoredM2: actualStoredM2 ?? this.actualStoredM2,
```

- [ ] **Step 2: Verify no compile errors**

```
flutter analyze lib/models/production_batch.dart
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/models/production_batch.dart
git commit -m "feat: add paving_stone_id, requested_m2, actual_stored_m2 to ProductionBatch"
```

---

## Task 4: Database Migration (version 39 → 40)

**Files:**
- Modify: `lib/services/Database/database_service.dart`

The current DB version is `39` (line 238). We bump to `40`.

- [ ] **Step 1: Update DB version constant**

Find line 238:
```dart
version: 39,
```
Change to:
```dart
version: 40,
```

- [ ] **Step 2: Add paving_stones table to `_onCreate`**

In `_onCreate`, find the `pallets` table CREATE TABLE block (around line 717) and insert the new table immediately after it, before `receptura_polozky` (around line 736):

```dart
      CREATE TABLE IF NOT EXISTS paving_stones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        length_mm REAL NOT NULL,
        width_mm REAL NOT NULL,
        thickness_mm REAL NOT NULL,
        pieces_per_layer INTEGER NOT NULL CHECK (pieces_per_layer > 0),
        layers_per_pallet INTEGER NOT NULL CHECK (layers_per_pallet > 0),
        user_id TEXT,
        created_at TEXT
      );
```

- [ ] **Step 3: Add migration block to `_onUpgrade`**

At the end of the `_onUpgrade` method (after the `if (oldVersion < 39)` block), add:

```dart
    if (oldVersion < 40) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS paving_stones (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          length_mm REAL NOT NULL,
          width_mm REAL NOT NULL,
          thickness_mm REAL NOT NULL,
          pieces_per_layer INTEGER NOT NULL CHECK (pieces_per_layer > 0),
          layers_per_pallet INTEGER NOT NULL CHECK (layers_per_pallet > 0),
          user_id TEXT,
          created_at TEXT
        )
      ''');
      await db.execute(
        'ALTER TABLE production_batches ADD COLUMN paving_stone_id INTEGER REFERENCES paving_stones(id)',
      );
      await db.execute(
        'ALTER TABLE production_batches ADD COLUMN requested_m2 REAL',
      );
      await db.execute(
        'ALTER TABLE production_batches ADD COLUMN actual_stored_m2 REAL',
      );
    }
```

- [ ] **Step 4: Verify compile**

```
flutter analyze lib/services/Database/database_service.dart
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/services/Database/database_service.dart
git commit -m "feat: db migration v40 — paving_stones table + 3 columns on production_batches"
```

---

## Task 5: PavingStoneService CRUD

**Files:**
- Modify: `lib/services/paving_stone_service.dart`

CRUD methods communicate with `DatabaseService` which holds the sqflite `Database`. Follow the same pattern as other services (pass `Database db` or use the singleton).

Check how existing services call the DB — look at e.g. `lib/services/Database/database_service.dart` for insert/query patterns. PavingStoneService should call `DatabaseService().database` to get the db instance, matching the project convention.

- [ ] **Step 1: Add CRUD methods to `paving_stone_service.dart`**

Append to the `PavingStoneService` class (below the static `calculate()` method):

```dart
  final DatabaseService _db = DatabaseService();

  Future<List<PavingStone>> getPavingStones(String? userId) async {
    final db = await _db.database;
    final maps = await db.query(
      'paving_stones',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return maps.map(PavingStone.fromMap).toList();
  }

  Future<int> insertPavingStone(PavingStone stone) async {
    final db = await _db.database;
    final map = stone.toMap()..remove('id');
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
```

Also add the required import at the top of the file:
```dart
import 'package:stock_pilot/services/Database/database_service.dart';
```

- [ ] **Step 2: Verify compile**

```
flutter analyze lib/services/paving_stone_service.dart
```
Expected: no errors.

- [ ] **Step 3: Run existing tests to confirm nothing broken**

```
flutter test
```
Expected: all existing tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/services/paving_stone_service.dart
git commit -m "feat: add PavingStoneService CRUD methods"
```

---

## Task 6: Modify production_batch_form_screen.dart

**Files:**
- Modify: `lib/screens/production/production_batch_form_screen.dart`

This is the largest change. The existing file is 365 lines. We add:
1. Load paving stones on init
2. State: `PavingStone? _selectedPavingStone`, `double _requestedM2`, `PavingStoneCalculation? _calc`
3. New product type picker that includes paving stones
4. Conditional form fields (m² vs PCS)
5. Live preview widget
6. Lock m² field if batch has pallets

- [ ] **Step 1: Add imports at the top of the file**

Add after the existing imports:
```dart
import 'package:stock_pilot/models/paving_stone.dart';
import 'package:stock_pilot/services/paving_stone_service.dart';
```

- [ ] **Step 2: Add state variables**

In `_ProductionBatchFormScreenState`, add after `_revenueTotal`:
```dart
// Paving stone m² mode
List<PavingStone> _pavingStones = [];
PavingStone? _selectedPavingStone;
double _requestedM2 = 0;
PavingStoneCalculation? _calc;
bool _hasPallets = false; // locks m² field if pallets exist
```

- [ ] **Step 3: Load paving stones in initState**

Replace `initState` to call `_loadPavingStones()`:
```dart
@override
void initState() {
  super.initState();
  _productionDate = widget.initialDate;
  _productType = _defaultProductTypes.first;
  _quantityProduced = 0;
  if (widget.editBatch != null) {
    _productionDate = DateTime.parse(widget.editBatch!.productionDate);
    _productType = widget.editBatch!.productType;
    _quantityProduced = widget.editBatch!.quantityProduced;
    _notes = widget.editBatch!.notes ?? '';
    _costTotal = widget.editBatch!.costTotal;
    _revenueTotal = widget.editBatch!.revenueTotal;
    _requestedM2 = widget.editBatch!.requestedM2 ?? 0;
    _loadRecipe();
    _checkHasPallets();
  }
  _loadPavingStones();
}
```

- [ ] **Step 4: Add helper methods**

Add after `_addCustomFraction()`:

```dart
Future<void> _loadPavingStones() async {
  // userId: use the same user isolation pattern as rest of app
  // DatabaseService exposes currentUserId or similar — adapt if needed
  final stones = await PavingStoneService().getPavingStones(
    _db.currentUserId,
  );
  if (mounted) setState(() => _pavingStones = stones);
}

Future<void> _checkHasPallets() async {
  if (widget.editBatch?.id == null) return;
  final pallets = await _db.getPalletsByBatchId(widget.editBatch!.id!);
  if (mounted) setState(() => _hasPallets = pallets.isNotEmpty);
}

void _onPavingStoneSelected(PavingStone? stone) {
  setState(() {
    _selectedPavingStone = stone;
    if (stone != null) {
      _productType = stone.name;
    }
    _calc = null;
  });
}

void _onM2Changed(String value) {
  final m2 = double.tryParse(value.replaceAll(',', '.'));
  if (m2 != null && m2 > 0 && _selectedPavingStone != null) {
    setState(() {
      _requestedM2 = m2;
      _calc = PavingStoneService.calculate(m2, _selectedPavingStone!);
      _quantityProduced = _calc!.totalPieces;
    });
  } else {
    setState(() {
      _calc = null;
      _quantityProduced = 0;
    });
  }
}
```

> **Note:** `_db.currentUserId` and `getPalletsByBatchId()` — check if these methods exist in `DatabaseService`. If not, use whatever userId/pallet lookup is already there (search for `userId` or `getPallet` in the service). Adapt the call accordingly.

- [ ] **Step 5: Replace product type dropdown and quantity field in `build()`**

Find the `DropdownButtonFormField<String>` for product type (around line 238) and the quantity `TextFormField` (around line 245). Replace this section with:

```dart
// --- Product Type ---
// Paving stones section
if (_pavingStones.isNotEmpty) ...[
  const Text('Typ výrobku — dlažba', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
  const SizedBox(height: 4),
  DropdownButtonFormField<PavingStone>(
    value: _selectedPavingStone,
    decoration: const InputDecoration(labelText: 'Vyberte dlažbu (m²)', border: OutlineInputBorder()),
    items: [
      const DropdownMenuItem<PavingStone>(value: null, child: Text('— Žiadna —')),
      ..._pavingStones.map((s) => DropdownMenuItem(
        value: s,
        child: Text('${s.name} (${s.m2PerPallet.toStringAsFixed(2)} m²/paleta)'),
      )),
    ],
    onChanged: _onPavingStoneSelected,
  ),
  const SizedBox(height: 8),
],
if (_selectedPavingStone == null)
  DropdownButtonFormField<String>(
    value: _productTypes.contains(_productType) ? _productType : null,
    decoration: const InputDecoration(labelText: 'Typ výrobku', border: OutlineInputBorder()),
    items: _productTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
    onChanged: (v) => setState(() => _productType = v ?? _defaultProductTypes.first),
  ),
const SizedBox(height: 16),

// --- Quantity: m² mode OR PCS mode ---
if (_selectedPavingStone != null) ...[
  AbsorbPointer(
    absorbing: _hasPallets,
    child: TextFormField(
      initialValue: _requestedM2 > 0 ? _requestedM2.toString() : '',
      decoration: InputDecoration(
        labelText: 'Požadované m²',
        border: const OutlineInputBorder(),
        suffixText: 'm²',
        helperText: _hasPallets ? 'Uzamknuté — palety už existujú' : null,
        filled: _hasPallets,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Zadajte m²';
        final n = double.tryParse(v.replaceAll(',', '.'));
        if (n == null || n <= 0) return 'Zadajte kladné číslo';
        return null;
      },
      onChanged: _onM2Changed,
    ),
  ),
  if (_calc != null) ...[
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '→ ${_calc!.totalPieces} ks  |  '
        '${_calc!.fullPallets} paliet'
        '${_calc!.remainingLayers > 0 ? " + ${_calc!.remainingLayers} vrstvy" : ""}  |  '
        'skutočné m²: ${_calc!.actualM2.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
  ],
] else
  TextFormField(
    initialValue: _quantityProduced == 0 ? '' : _quantityProduced.toString(),
    decoration: const InputDecoration(
      labelText: 'Počet vyrobených kusov',
      border: OutlineInputBorder(),
    ),
    keyboardType: TextInputType.number,
    validator: (v) {
      if (v == null || v.isEmpty) return 'Zadajte počet';
      final n = int.tryParse(v);
      if (n == null || n < 0) return 'Neplatný počet';
      return null;
    },
    onSaved: (v) => _quantityProduced = int.tryParse(v ?? '0') ?? 0,
    onChanged: (v) => _quantityProduced = int.tryParse(v) ?? 0,
  ),
const SizedBox(height: 20),
```

- [ ] **Step 6: Update `_save()` to persist paving stone fields**

In `_save()`, find where `ProductionBatch` is created and add the new fields:
```dart
final batch = ProductionBatch(
  id: widget.editBatch?.id,
  productionDate: dateStr,
  productType: _productType,
  quantityProduced: _quantityProduced,
  notes: _notes.isEmpty ? null : _notes,
  createdAt: widget.editBatch?.createdAt ?? DateTime.now().toIso8601String(),
  costTotal: _costTotal,
  revenueTotal: _revenueTotal,
  // Paving stone fields
  pavingStoneId: _selectedPavingStone?.id,
  requestedM2: _selectedPavingStone != null ? _requestedM2 : null,
  actualStoredM2: _calc?.actualM2,
);
```

- [ ] **Step 7: Verify compile**

```
flutter analyze lib/screens/production/production_batch_form_screen.dart
```
Expected: no errors.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/production/production_batch_form_screen.dart
git commit -m "feat: production form — auto-switch to m² mode for paving stones"
```

---

## Task 7: Modify create_pallets_dialog.dart

**Files:**
- Modify: `lib/screens/pallet/create_pallets_dialog.dart`

The dialog receives a `ProductionBatch`. When `batch.pavingStoneId != null`, we load the stone, lock `piecesPerPallet`, suggest `fullPallets` count, and create a partial pallet if needed.

- [ ] **Step 1: Add imports**

Add at the top:
```dart
import 'package:stock_pilot/models/paving_stone.dart';
import 'package:stock_pilot/services/paving_stone_service.dart';
```

- [ ] **Step 2: Add state and init logic**

In `_CreatePalletsDialogState`, add:
```dart
PavingStone? _stone;
PavingStoneCalculation? _calc;
```

Update `initState()`:
```dart
@override
void initState() {
  super.initState();
  if (widget.batch.pavingStoneId != null) {
    _initPavingStoneMode();
  } else {
    _initGenericMode();
  }
}

void _initGenericMode() {
  final total = widget.batch.quantityProduced;
  final defaultCount = total > 0 ? 5.clamp(1, total) : 1;
  final defaultQty = total > 0 ? (total / defaultCount).floor().clamp(1, total) : 1;
  _qtyController = TextEditingController(text: '$defaultQty');
  _countController = TextEditingController(text: '$defaultCount');
  _qtyController.addListener(_onQtyChanged);
  _countController.addListener(_onCountChanged);
}

Future<void> _initPavingStoneMode() async {
  // Load stone to get piecesPerPallet
  // We stored requestedM2 on the batch — recalculate to get fullPallets/remainingLayers
  final service = PavingStoneService();
  // Fetch stone by id — add a getPavingStoneById method to the service
  final stone = await service.getPavingStoneById(widget.batch.pavingStoneId!);
  if (stone == null || !mounted) return;

  final m2 = widget.batch.requestedM2 ?? 0;
  final calc = m2 > 0 ? PavingStoneService.calculate(m2, stone) : null;

  setState(() {
    _stone = stone;
    _calc = calc;
    _qtyController = TextEditingController(text: '${stone.piecesPerPallet}');
    _countController = TextEditingController(
      text: '${calc?.fullPallets ?? 1}',
    );
    // In paving stone mode, qty is locked — no listeners needed
  });
}
```

- [ ] **Step 3: Add `getPavingStoneById` to PavingStoneService**

In `lib/services/paving_stone_service.dart`, add:
```dart
  Future<PavingStone?> getPavingStoneById(int id) async {
    final db = await _db.database;
    final maps = await db.query('paving_stones', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return PavingStone.fromMap(maps.first);
  }
```

- [ ] **Step 4: Update `_create()` for paving stone mode**

Replace `_create()` with a branched version:

```dart
Future<List<Pallet>?> _create() async {
  if (_stone != null && _calc != null) {
    return _createPavingStonePallets();
  }
  return _createGenericPallets();
}

Future<List<Pallet>?> _createGenericPallets() async {
  // Existing logic unchanged
  final qty = int.tryParse(_qtyController.text);
  final count = int.tryParse(_countController.text);
  if (qty == null || qty <= 0 || count == null || count <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zadajte platný počet kusov a počet paliet')),
    );
    return null;
  }
  final total = qty * count;
  if (total > widget.batch.quantityProduced) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Celkom $total kusov prevyšuje počet vyrobených (${widget.batch.quantityProduced}).')),
    );
    return null;
  }
  final db = DatabaseService();
  final created = <Pallet>[];
  for (var i = 0; i < count; i++) {
    final id = await db.insertPallet(Pallet(
      batchId: widget.batch.id!,
      productType: widget.batch.productType,
      quantity: qty,
      status: PalletStatus.naSklade,
    ));
    final p = await db.getPalletById(id);
    if (p != null) created.add(p);
  }
  return created;
}

Future<List<Pallet>?> _createPavingStonePallets() async {
  final count = int.tryParse(_countController.text) ?? _calc!.fullPallets;
  final db = DatabaseService();
  final created = <Pallet>[];

  // Full pallets
  for (var i = 0; i < count; i++) {
    final id = await db.insertPallet(Pallet(
      batchId: widget.batch.id!,
      productType: widget.batch.productType,
      quantity: _stone!.piecesPerPallet,
      status: PalletStatus.naSklade,
    ));
    final p = await db.getPalletById(id);
    if (p != null) created.add(p);
  }

  // Partial pallet (if remaining layers exist)
  if (_calc!.partialPieces > 0) {
    final id = await db.insertPallet(Pallet(
      batchId: widget.batch.id!,
      productType: '${widget.batch.productType} (neúplná)',
      quantity: _calc!.partialPieces,
      status: PalletStatus.naSklade,
    ));
    final p = await db.getPalletById(id);
    if (p != null) created.add(p);
  }

  return created;
}
```

- [ ] **Step 5: Update `build()` to show paving stone info when in paving stone mode**

In the `AlertDialog` content, add a conditional branch. When `_stone != null`:

```dart
if (_stone != null) ...[
  Text(
    'Šarža: ${widget.batch.productType} (${widget.batch.requestedM2?.toStringAsFixed(2) ?? "?"} m²)',
    style: Theme.of(context).textTheme.bodyMedium,
  ),
  const SizedBox(height: 8),
  if (_calc != null)
    Text(
      '→ ${_calc!.fullPallets} celých paliet'
      '${_calc!.remainingLayers > 0 ? " + 1 neúplná (${_calc!.remainingLayers} vrstvy)" : ""}',
      style: const TextStyle(fontWeight: FontWeight.w500),
    ),
  const SizedBox(height: 12),
  TextFormField(
    controller: _qtyController,
    readOnly: true,
    decoration: const InputDecoration(
      labelText: 'Kusov na paletu (uzamknuté)',
      border: OutlineInputBorder(),
      filled: true,
    ),
  ),
  const SizedBox(height: 12),
  TextField(
    controller: _countController,
    decoration: const InputDecoration(
      labelText: 'Počet celých paliet',
      border: OutlineInputBorder(),
    ),
    keyboardType: TextInputType.number,
  ),
] else ...[
  // existing generic fields
  Text(
    'Šarža: ${widget.batch.productType} (${widget.batch.quantityProduced} ks)',
    style: Theme.of(context).textTheme.bodyMedium,
  ),
  const SizedBox(height: 16),
  TextField(
    controller: _qtyController,
    decoration: const InputDecoration(
      labelText: 'Počet kusov na jednu paletu',
      border: OutlineInputBorder(),
    ),
    keyboardType: TextInputType.number,
  ),
  const SizedBox(height: 12),
  TextField(
    controller: _countController,
    decoration: const InputDecoration(
      labelText: 'Počet paliet',
      border: OutlineInputBorder(),
    ),
    keyboardType: TextInputType.number,
  ),
],
```

- [ ] **Step 6: Verify compile**

```
flutter analyze lib/screens/pallet/create_pallets_dialog.dart lib/services/paving_stone_service.dart
```
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/pallet/create_pallets_dialog.dart lib/services/paving_stone_service.dart
git commit -m "feat: create_pallets_dialog — paving stone mode with layer-aware partial pallet"
```

---

## Task 8: Paving Stone Catalog Screen

**Files:**
- Create: `lib/screens/paving_stone/paving_stone_list_screen.dart`

A simple list + add/edit dialog. Follows the same UI pattern as other list screens in the app (dark theme, AppColors).

- [ ] **Step 1: Create the screen**

Create `lib/screens/paving_stone/paving_stone_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:stock_pilot/models/paving_stone.dart';
import 'package:stock_pilot/services/paving_stone_service.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/theme/app_theme.dart';

class PavingStoneListScreen extends StatefulWidget {
  const PavingStoneListScreen({super.key});

  @override
  State<PavingStoneListScreen> createState() => _PavingStoneListScreenState();
}

class _PavingStoneListScreenState extends State<PavingStoneListScreen> {
  final _service = PavingStoneService();
  List<PavingStone> _stones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = DatabaseService.currentUserId;
    final stones = await _service.getPavingStones(userId);
    if (mounted) setState(() { _stones = stones; _loading = false; });
  }

  Future<void> _openForm({PavingStone? stone}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _PavingStoneFormDialog(stone: stone),
    );
    if (result == true) _load();
  }

  Future<void> _delete(PavingStone stone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vymazať dlažbu?'),
        content: Text('${stone.name} bude vymazaná. Výrobné šarže ostanú, ale stratia väzbu na dlažbu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušiť')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Vymazať')),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deletePavingStone(stone.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Katalóg dlažieb', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stones.isEmpty
              ? const Center(child: Text('Žiadne dlažby. Pridajte prvú.', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  itemCount: _stones.length,
                  itemBuilder: (_, i) {
                    final s = _stones[i];
                    return ListTile(
                      title: Text(s.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${s.lengthMm.toInt()}×${s.widthMm.toInt()}×${s.thicknessMm.toInt()} mm  |  '
                        '${s.piecesPerLayer} ks/vrstva  |  ${s.layersPerPallet} vrstiev/paleta  |  '
                        '${s.m2PerPallet.toStringAsFixed(2)} m²/paleta',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _openForm(stone: s)),
                          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(s)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _PavingStoneFormDialog extends StatefulWidget {
  final PavingStone? stone;
  const _PavingStoneFormDialog({this.stone});

  @override
  State<_PavingStoneFormDialog> createState() => _PavingStoneFormDialogState();
}

class _PavingStoneFormDialogState extends State<_PavingStoneFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = PavingStoneService();

  late final TextEditingController _name;
  late final TextEditingController _length;
  late final TextEditingController _width;
  late final TextEditingController _thickness;
  late final TextEditingController _pcsPerLayer;
  late final TextEditingController _layersPerPallet;

  @override
  void initState() {
    super.initState();
    final s = widget.stone;
    _name          = TextEditingController(text: s?.name ?? '');
    _length        = TextEditingController(text: s?.lengthMm.toString() ?? '');
    _width         = TextEditingController(text: s?.widthMm.toString() ?? '');
    _thickness     = TextEditingController(text: s?.thicknessMm.toString() ?? '');
    _pcsPerLayer   = TextEditingController(text: s?.piecesPerLayer.toString() ?? '');
    _layersPerPallet = TextEditingController(text: s?.layersPerPallet.toString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _length, _width, _thickness, _pcsPerLayer, _layersPerPallet]) c.dispose();
    super.dispose();
  }

  String? _positiveDouble(String? v) {
    if (v == null || v.isEmpty) return 'Povinné';
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n <= 0) return 'Zadajte kladné číslo';
    return null;
  }

  String? _positiveInt(String? v) {
    if (v == null || v.isEmpty) return 'Povinné';
    final n = int.tryParse(v);
    if (n == null || n <= 0) return 'Minimálne 1';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = DatabaseService.currentUserId;
    final stone = PavingStone(
      id: widget.stone?.id,
      name: _name.text.trim(),
      lengthMm: double.parse(_length.text.replaceAll(',', '.')),
      widthMm: double.parse(_width.text.replaceAll(',', '.')),
      thicknessMm: double.parse(_thickness.text.replaceAll(',', '.')),
      piecesPerLayer: int.parse(_pcsPerLayer.text),
      layersPerPallet: int.parse(_layersPerPallet.text),
      userId: userId,
    );
    if (widget.stone?.id != null) {
      await _service.updatePavingStone(stone);
    } else {
      await _service.insertPavingStone(stone);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.stone != null ? 'Upraviť dlažbu' : 'Nová dlažba'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Názov', border: OutlineInputBorder()), validator: (v) => v == null || v.trim().isEmpty ? 'Povinné' : null),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _length, decoration: const InputDecoration(labelText: 'Dĺžka (mm)', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: _positiveDouble)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _width, decoration: const InputDecoration(labelText: 'Šírka (mm)', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: _positiveDouble)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _thickness, decoration: const InputDecoration(labelText: 'Výška (mm)', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: _positiveDouble)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _pcsPerLayer, decoration: const InputDecoration(labelText: 'Ks/vrstva', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: _positiveInt)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _layersPerPallet, decoration: const InputDecoration(labelText: 'Vrstvy/paleta', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: _positiveInt)),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušiť')),
        FilledButton(onPressed: _save, child: const Text('Uložiť')),
      ],
    );
  }
}
```

- [ ] **Step 2: Register the route**

Find the app router (typically `lib/main.dart` or a routes file). Add:
```dart
'/paving-stones': (_) => const PavingStoneListScreen(),
```
Also add a navigation entry point — e.g. in Settings screen or the production menu.

- [ ] **Step 3: Verify compile**

```
flutter analyze lib/screens/paving_stone/paving_stone_list_screen.dart
```
Expected: no errors.

- [ ] **Step 4: Run all tests**

```
flutter test
```
Expected: all tests PASS.

- [ ] **Step 5: Final commit**

```bash
git add lib/screens/paving_stone/paving_stone_list_screen.dart
git commit -m "feat: add PavingStoneListScreen catalog with add/edit/delete"
```

---

## Adaptation Notes

> These points require judgment calls during implementation — adapt based on what you find in the code:

1. **`_db.currentUserId`** — search `database_service.dart` for how `user_id` is fetched for the current session. It may be a field, a method, or passed via `SharedPreferences`. Use the same pattern.

2. **`_db.getPalletsByBatchId(batchId)` (confirmed method name)** — search `database_service.dart` for existing pallet query methods. If one exists with a `batchId` parameter, use it. If not, query directly: `db.query('pallets', where: 'batch_id = ?', whereArgs: [batchId])`.

3. **Route registration** — search `main.dart` or find where `MaterialApp` routes are defined. Follow the existing pattern exactly.
