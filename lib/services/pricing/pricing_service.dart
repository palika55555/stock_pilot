import '../../models/pricing_rule.dart';
import '../../models/product.dart';
import '../Database/database_service.dart';
import '../api_sync_service.dart' show syncPricingRulesToBackend, getBackendToken;

/// Servisná vrstva pre Rozšírenú cenotvorbu.
///
/// Zodpoveda za:
///  - CRUD pravidiel (uloženie cez DatabaseService)
///  - výpočet efektívnej predajnej ceny (resolveEffectivePrice)
///  - validáciu (cena nesmie byť nižšia ako nákupná cena)
class PricingService {
  final DatabaseService _db = DatabaseService();

  // ──────────────────────────────────────────────────────────
  // CRUD
  // ──────────────────────────────────────────────────────────

  Future<List<PricingRule>> getRulesForProduct(String productUniqueId) =>
      _db.getPricingRules(productUniqueId);

  Future<int> addRule(PricingRule rule) => _db.insertPricingRule(rule);

  Future<int> updateRule(PricingRule rule) => _db.updatePricingRule(rule);

  Future<int> removeRule(int id) => _db.deletePricingRule(id);

  /// Uloží celý zoznam pravidiel pre produkt (DELETE all + INSERT).
  /// Rovnaký vzor ako saveRecepturaZlozky.
  /// Po lokálnom uložení asynchrónne synchronizuje na backend.
  Future<void> savePricingRules(
    String productUniqueId,
    List<PricingRule> rules,
  ) async {
    await _db.deletePricingRulesByProductId(productUniqueId);
    for (final rule in rules) {
      final r = rule.copyWith(productUniqueId: productUniqueId);
      await _db.insertPricingRule(r);
    }
    // Asynchrónna sync na backend (fire-and-forget, neprerušuje UI)
    final token = getBackendToken();
    if (token != null && token.isNotEmpty) {
      final payload = rules
          .map((r) => r.copyWith(productUniqueId: productUniqueId).toMap())
          .toList();
      syncPricingRulesToBackend(productUniqueId, payload, token).ignore();
    }
  }

  /// Zmaže všetky pravidlá produktu (pri vypnutí hasExtendedPricing).
  Future<void> clearRulesForProduct(String productUniqueId) =>
      _db.deletePricingRulesByProductId(productUniqueId);

  // ──────────────────────────────────────────────────────────
  // Biznis logika
  // ──────────────────────────────────────────────────────────

  /// Vypočíta efektívnu predajnú cenu s DPH na základe pravidiel.
  ///
  /// Algoritmus:
  ///  1. Ak produkt nemá rozšírenú cenotvorbu alebo rules je prázdny → vráti [product.price].
  ///  2. Filtruje pravidlá podľa množstva, skupiny zákazníka a dátumu platnosti.
  ///  3. Z vyhovujúcich pravidiel vyberie to s najnižšou cenou.
  ///  4. Ak žiadne pravidlo nevyhovuje → vráti [product.price] ako fallback.
  double resolveEffectivePrice({
    required Product product,
    required List<PricingRule> rules,
    double quantity = 1,
    String? customerGroup,
    DateTime? date,
  }) {
    if (!product.hasExtendedPricing || rules.isEmpty) {
      return product.price;
    }

    final now = date ?? DateTime.now();

    final matched = rules.where((r) {
      // Podmienka množstva
      final qtyOk = quantity >= r.quantityFrom &&
          (r.quantityTo == null || quantity <= r.quantityTo!);

      // Podmienka skupiny zákazníka
      final groupOk = r.customerGroup == null ||
          r.customerGroup!.isEmpty ||
          r.customerGroup == customerGroup;

      // Podmienka dátumu platnosti
      final fromOk = r.validFrom == null || !now.isBefore(r.validFrom!);
      final toOk = r.validTo == null || !now.isAfter(r.validTo!);

      return qtyOk && groupOk && fromOk && toOk;
    }).toList();

    if (matched.isEmpty) return product.price;

    // Priorita: najnižšia cena (najvýhodnejšia pre zákazníka)
    matched.sort((a, b) => a.price.compareTo(b.price));
    return matched.first.price;
  }

  /// Validácia pravidla: efektívna cena nesmie byť nižšia ako nákupná cena bez DPH.
  ///
  /// Vyhodí [PricingValidationException] ak cena je nižšia ako nákupná cena.
  void validateRule(PricingRule rule, Product product) {
    if (product.purchasePriceWithoutVat > 0 &&
        rule.price < product.purchasePriceWithoutVat) {
      throw PricingValidationException(
        rulePrice: rule.price,
        purchasePriceWithoutVat: product.purchasePriceWithoutVat,
        productName: product.name,
      );
    }
  }

  /// Vráti true ak je pravidlo aktívne k danému dátumu.
  bool isRuleActive(PricingRule rule, [DateTime? date]) {
    final now = date ?? DateTime.now();
    final fromOk = rule.validFrom == null || !now.isBefore(rule.validFrom!);
    final toOk = rule.validTo == null || !now.isAfter(rule.validTo!);
    return fromOk && toOk;
  }
}

// ──────────────────────────────────────────────────────────
// Výnimky
// ──────────────────────────────────────────────────────────

class PricingValidationException implements Exception {
  final double rulePrice;
  final double purchasePriceWithoutVat;
  final String productName;

  const PricingValidationException({
    required this.rulePrice,
    required this.purchasePriceWithoutVat,
    required this.productName,
  });

  @override
  String toString() =>
      'Rozšírená cena (${rulePrice.toStringAsFixed(2)} €) nesmie byť nižšia '
      'ako nákupná cena bez DPH (${purchasePriceWithoutVat.toStringAsFixed(2)} €) '
      'pre produkt "$productName".';
}
