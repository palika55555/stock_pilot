# Design Spec: Paving Stone m²-First Production Module

**Date:** 2026-03-25
**Status:** Approved
**Scope:** Production & Palletization module — m² input for paving stones

---

## 1. Context

The stock_pilot Flutter app manages concrete production including paving stones (zamková dlažba).
Currently all production quantities are entered in pieces (PCS). This spec introduces m²-first
input for paving stones, with automatic conversion and rounding to the nearest full layer (vrstva)
as the atomic unit.

**Stack:** Flutter, SQLite (sqflite), Provider pattern, Windows-primary.

---

## 2. Core Rule

> All paving stone production inputs MUST use m² (square meters), not PCS.
> The system converts m² → pieces internally, rounding UP to the nearest full layer.
> A layer (vrstva) is always the smallest unit. A pallet is a grouping of layers.

---

## 3. Data Layer

### 3.1 New table: `paving_stones`

```sql
CREATE TABLE paving_stones (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  length_mm REAL NOT NULL,
  width_mm REAL NOT NULL,
  thickness_mm REAL NOT NULL,
  pieces_per_layer INTEGER NOT NULL CHECK (pieces_per_layer > 0),
  layers_per_pallet INTEGER NOT NULL CHECK (layers_per_pallet > 0),
  user_id INTEGER,
  created_at TEXT
);
```

**user_id scope:** Follows the existing per-user isolation pattern across all tables.
All CRUD queries in `PavingStoneService` are scoped by `user_id`. The column is kept for
consistency even in single-user deployments.

### 3.2 Modified table: `production_batches`

Migration via `ALTER TABLE` (see Section 7 for version):

```sql
ALTER TABLE production_batches ADD COLUMN paving_stone_id INTEGER REFERENCES paving_stones(id);
ALTER TABLE production_batches ADD COLUMN requested_m2 REAL;
ALTER TABLE production_batches ADD COLUMN actual_stored_m2 REAL;
```

**`quantity_produced` behavior:** For paving stone batches, `quantity_produced` is always
overwritten with `totalPieces` from `calculate()` — the rounded-up piece count. It is never
entered manually by the user. For non-paving-stone batches, behavior is unchanged.

**`actual_stored_m2` write lifecycle:** Written once at save time (`quantity_produced * m2PerPiece`).
Not updated retroactively. If pallets have already been created for a batch, the form does not
allow editing `requested_m2` (the field is locked). This prevents drift between stored m² and
existing pallet records.

### 3.3 New Dart model: `PavingStone`

File: `lib/models/paving_stone.dart`

```dart
class PavingStone {
  final int? id;
  final String name;
  final double lengthMm;
  final double widthMm;
  final double thicknessMm;
  final int piecesPerLayer;      // atomic unit count
  final int layersPerPallet;
  final int? userId;
  final DateTime? createdAt;

  double get m2PerPiece    => (lengthMm * widthMm) / 1_000_000;
  double get m2PerLayer    => piecesPerLayer * m2PerPiece;
  double get m2PerPallet   => layersPerPallet * m2PerLayer;
  int    get piecesPerPallet => piecesPerLayer * layersPerPallet;
}
```

### 3.4 Updated Dart model: `ProductionBatch`

Add nullable fields:
- `int? pavingStoneId`
- `double? requestedM2`
- `double? actualStoredM2`

---

## 4. Business Logic

File: `lib/services/paving_stone_service.dart`

### 4.1 CRUD

All queries scoped by `userId`:
- `Future<List<PavingStone>> getPavingStones(int userId)`
- `Future<int> insertPavingStone(PavingStone stone)`
- `Future<void> updatePavingStone(PavingStone stone)`
- `Future<void> deletePavingStone(int id)`

### 4.2 Conversion (pure, stateless, testable)

**Input validation** (enforced before calling `calculate()`):
- `requestedM2` must be > 0 (validated in UI; `calculate()` asserts > 0 defensively)
- `stone.piecesPerLayer` and `stone.layersPerPallet` must be > 0 (enforced by DB constraint
  and catalog form validation; never reached in `calculate()` if catalog is valid)

```dart
PavingStoneCalculation calculate(double requestedM2, PavingStone stone) {
  assert(requestedM2 > 0);
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
    partialPieces: partialPieces,       // pieces on the last partial pallet
    actualM2: actualM2,
  );
}
```

`PavingStoneCalculation` is an immutable value object (all fields final).

---

## 5. State Management

Extend existing `ProductionBatchProvider` (or equivalent Provider):

- `List<PavingStone> pavingStones` + `loadPavingStones()`
- `PavingStone? selectedPavingStone`
- `PavingStoneCalculation? currentCalculation` — recomputed on every m² input change

No new Provider class needed.

---

## 6. UI Changes

### 6.1 `production_batch_form_screen.dart`

- Product type field gains a combined source: free-text list + PavingStone catalog (shown as a
  separate labeled section in the dropdown)
- When user selects a `PavingStone`:
  - Form **auto-switches** to m² mode
  - "Počet kusov" field is hidden
  - "Požadované m²" text field appears
  - Input validation: must be a positive number; form blocks save if invalid
  - Live preview updates on every valid keystroke:
    ```
    → 120 kusov  |  1 paleta + 2 vrstvy  |  skutočné m²: 12.0
    ```
- If pallets have already been created for this batch, `requested_m2` is locked (read-only)
- On save: `calculate()` is called; `quantity_produced`, `requested_m2`, `actual_stored_m2`,
  and `paving_stone_id` are all persisted

### 6.2 `create_pallets_dialog.dart`

When batch has `paving_stone_id`:
- "Kusov na paletu" field is **auto-filled** and locked to `stone.piecesPerPallet` (read-only)
- Suggested pallet count pre-filled from `calculation.fullPallets`
- If `remainingLayers > 0`: a partial pallet is created automatically with
  `calculation.partialPieces` pieces and labeled visually as "Neúplná paleta (X vrstvy)"
- User can adjust count of full pallets; partial pallet is always added if it exists

### 6.3 New screen: `lib/screens/paving_stone/paving_stone_list_screen.dart`

CRUD catalog for PavingStone definitions:
- List view of all stones for current user
- Add/Edit dialog: name, length_mm, width_mm, thickness_mm, pieces_per_layer (min 1),
  layers_per_pallet (min 1) — all validated before save
- Delete (with confirmation if stone is referenced by any production batch)

---

## 7. Database Migration

- **Current DB version:** N (existing)
- **New DB version:** N+1
- **`onUpgrade` handler:** runs when oldVersion < N+1:
  ```sql
  CREATE TABLE paving_stones (...);
  ALTER TABLE production_batches ADD COLUMN paving_stone_id INTEGER REFERENCES paving_stones(id);
  ALTER TABLE production_batches ADD COLUMN requested_m2 REAL;
  ALTER TABLE production_batches ADD COLUMN actual_stored_m2 REAL;
  ```
- **`onDowngrade`:** throws `DatabaseException` (standard policy — no down-migration supported)
- Existing production batch rows are unaffected; new columns default to NULL

---

## 8. Files Affected / Created

| Action | File |
|--------|------|
| CREATE | `lib/models/paving_stone.dart` |
| CREATE | `lib/services/paving_stone_service.dart` |
| CREATE | `lib/screens/paving_stone/paving_stone_list_screen.dart` |
| MODIFY | `lib/models/production_batch.dart` |
| MODIFY | `lib/services/Database/database_service.dart` |
| MODIFY | `lib/screens/production/production_batch_form_screen.dart` |
| MODIFY | `lib/screens/pallet/create_pallets_dialog.dart` |
| MODIFY | `lib/Providers/` (ProductionBatch provider) |

---

## 9. Testing

**Unit tests** for `calculate()` in `PavingStoneService`:
- Exact m² (no rounding): `requestedM2 == m2PerLayer * N` → `remainingLayers == 0`
- Layer rounding: 12 m² on stone with 10.8 m²/pallet → `fullPallets=1, remainingLayers=2`
- Single layer: very small m² → totalLayers=1, fullPallets=0, remainingLayers=1
- Zero m² input: assert fires (invalid input guard)

**Widget tests:**
- Auto-switch in production form: selecting a PavingStone hides PCS field, shows m² field
- Dialog auto-fill: `create_pallets_dialog` shows locked `piecesPerPallet` and partial pallet
  row when `remainingLayers > 0`

**Catalog validation tests:**
- `pieces_per_layer = 0` rejected by form before DB write
- `layers_per_pallet = 0` rejected by form before DB write
