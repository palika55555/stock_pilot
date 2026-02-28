import '../../models/product.dart';
import '../../models/receptura_polozka.dart';
import '../../models/skladova_karta.dart';
import '../../models/typ_karty.dart';
import '../Database/database_service.dart';

/// Výnimka pri nedostatočnom množstve suroviny pri výdaji receptúry.
class NedostatokSurovinyException implements Exception {
  final String kartaId;
  final String? nazov;
  final double potrebne;
  final double dostupne;

  NedostatokSurovinyException({
    required this.kartaId,
    this.nazov,
    required this.potrebne,
    required this.dostupne,
  });

  @override
  String toString() =>
      'Nedostatočné množstvo suroviny${nazov != null ? ': $nazov' : ''} (ID: $kartaId). Potrebné: $potrebne, dostupné: $dostupne.';
}

/// Služba pre výpočet nákladovej ceny receptúr a výdaj zo skladu (vrátane odťažovania surovín).
class RecepturaService {
  final DatabaseService _db = DatabaseService();

  /// Zaokrúhli na 3 desatinné miesta (ochrana pred chybami float).
  static double round3(double value) {
    return (value * 1000).round() / 1000;
  }

  /// Vypočíta nákladovú cenu receptúry ako súčet (mnozstvo * nakupnaCena) pre každú zložku.
  /// Suroviny sa hľadajú vo [vsetkyKarty] podľa [RecepturaPolozka.idSuroviny].
  /// Ak surovina chýba, jej príspevok je 0 (nevyhadzuje výnimku).
  double vypocitajNakladovuCenu(
    SkladovaKarta receptura,
    List<SkladovaKarta> vsetkyKarty,
  ) {
    if (!receptura.typ.isReceptura || receptura.zlozky.isEmpty) {
      return receptura.nakupnaCena;
    }
    double sum = 0.0;
    final kartyById = {for (final k in vsetkyKarty) k.id: k};
    for (final zlozka in receptura.zlozky) {
      final surovina = kartyById[zlozka.idSuroviny];
      if (surovina == null) continue;
      final prispevok = zlozka.mnozstvo * surovina.nakupnaCena;
      sum += round3(prispevok);
    }
    return round3(sum);
  }

  /// Vydá zo skladu množstvo [mnozstvo] pre kartu [kartaId].
  /// Ak je karta receptúra, rekurzívne odťahuje suroviny (zložky).
  /// Inak zníži [mnozstvoNaSklade] (v DB [Product.qty]) priamo.
  /// Pri nedostatočnom stave vyhodí [NedostatokSurovinyException].
  Future<void> vydatZoSkladu({
    required String kartaId,
    required double mnozstvo,
  }) async {
    if (mnozstvo <= 0) return;
    final product = await _db.getProductByUniqueId(kartaId);
    if (product == null) {
      throw Exception('Karta s ID $kartaId neexistuje.');
    }
    final typ = typKartyFromString(product.cardType);
    if (typ == TypKarty.receptura) {
      final zlozky = await _db.getRecepturaPolozky(kartaId);
      if (zlozky.isEmpty) {
        throw Exception('Receptúra $kartaId nemá definované zložky.');
      }
      for (final zlozka in zlozky) {
        final potrebneMnozstvo = round3(mnozstvo * zlozka.mnozstvo);
        if (potrebneMnozstvo <= 0) continue;
        await vydatZoSkladu(
          kartaId: zlozka.idSuroviny,
          mnozstvo: potrebneMnozstvo,
        );
      }
    } else {
      final qtyToDeduct = mnozstvo.round();
      if (product.qty < qtyToDeduct) {
        throw NedostatokSurovinyException(
          kartaId: kartaId,
          nazov: product.name,
          potrebne: qtyToDeduct.toDouble(),
          dostupne: product.qty.toDouble(),
        );
      }
      final newQty = product.qty - qtyToDeduct;
      final updated = Product(
        uniqueId: product.uniqueId,
        name: product.name,
        plu: product.plu,
        ean: product.ean,
        category: product.category,
        qty: newQty,
        unit: product.unit,
        price: product.price,
        withoutVat: product.withoutVat,
        vat: product.vat,
        discount: product.discount,
        lastPurchasePrice: product.lastPurchasePrice,
        lastPurchasePriceWithoutVat: product.lastPurchasePriceWithoutVat,
        lastPurchaseDate: product.lastPurchaseDate,
        currency: product.currency,
        location: product.location,
        purchasePrice: product.purchasePrice,
        purchasePriceWithoutVat: product.purchasePriceWithoutVat,
        purchaseVat: product.purchaseVat,
        recyclingFee: product.recyclingFee,
        productType: product.productType,
        supplierName: product.supplierName,
        kindId: product.kindId,
        warehouseId: product.warehouseId,
        linkedProductUniqueId: product.linkedProductUniqueId,
        minQuantity: product.minQuantity,
        allowAtCashRegister: product.allowAtCashRegister,
        showInPriceList: product.showInPriceList,
        isActive: product.isActive,
        temporarilyUnavailable: product.temporarilyUnavailable,
        stockGroup: product.stockGroup,
        cardType: product.cardType,
        hasExtendedPricing: product.hasExtendedPricing,
        ibaCeleMnozstva: product.ibaCeleMnozstva,
      );
      await _db.updateProduct(updated);
    }
  }

  /// Načíta [SkladovaKarta] z DB podľa [productUniqueId] (vrátane zložiek receptúry).
  Future<SkladovaKarta?> getSkladovaKarta(String productUniqueId) async {
    final product = await _db.getProductByUniqueId(productUniqueId);
    if (product == null) return null;
    final zlozky = typKartyFromString(product.cardType) == TypKarty.receptura
        ? await _db.getRecepturaPolozky(productUniqueId)
        : <RecepturaPolozka>[];
    return SkladovaKarta.fromProduct(product, zlozky: zlozky);
  }

  /// Uloží zložky receptúry (vymaže staré a vloží nové).
  Future<void> saveRecepturaZlozky(
    String recepturaKartaId,
    List<RecepturaPolozka> zlozky,
  ) async {
    await _db.deleteRecepturaPolozkyByRecepturaKartaId(recepturaKartaId);
    for (final z in zlozky) {
      await _db.insertRecepturaPolozka(z, recepturaKartaId);
    }
  }

  /// Načíta všetky skladové karty (produkty + zložky receptúr). Vhodné pre [vypocitajNakladovuCenu].
  Future<List<SkladovaKarta>> getAllSkladoveKarty() async {
    final products = await _db.getProducts();
    final list = <SkladovaKarta>[];
    for (final p in products) {
      final id = p.uniqueId ?? '';
      final zlozky = typKartyFromString(p.cardType) == TypKarty.receptura
          ? await _db.getRecepturaPolozky(id)
          : <RecepturaPolozka>[];
      list.add(SkladovaKarta.fromProduct(p, zlozky: zlozky));
    }
    return list;
  }
}
