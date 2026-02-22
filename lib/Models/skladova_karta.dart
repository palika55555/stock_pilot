import 'package:flutter/material.dart';

import 'product.dart';
import 'receptura_polozka.dart';
import 'typ_karty.dart';

/// Skladová karta – jednotný model pre jednoduché karty aj receptúry (kalkulácie).
/// Môže byť zostavená z [Product] a voliteľného zoznamu [RecepturaPolozka] pre typ receptúra.
class SkladovaKarta {
  final String id;
  final String cislo;
  final String nazov;
  final TypKarty typ;
  final String mernaJednotka;
  final double mnozstvoNaSklade;
  final double nakupnaCena;
  final bool ibaCeleMnozstva;
  /// Minimálne množstvo – pre getter [isLowStock].
  final double minimalneMnozstvo;
  final bool hasExtendedPricing;
  final bool temporarilyUnavailable;
  final bool isActive;
  /// Zložky receptúry (suroviny). Používa sa len ak [typ] == [TypKarty.receptura].
  final List<RecepturaPolozka> zlozky;

  const SkladovaKarta({
    required this.id,
    required this.cislo,
    required this.nazov,
    required this.typ,
    required this.mernaJednotka,
    required this.mnozstvoNaSklade,
    required this.nakupnaCena,
    this.ibaCeleMnozstva = false,
    this.minimalneMnozstvo = 0.0,
    this.hasExtendedPricing = false,
    this.temporarilyUnavailable = false,
    this.isActive = true,
    this.zlozky = const [],
  });

  /// Dostupnosť pre predaj (aktívna a nie dočasne nedostupná).
  bool get isAvailable => isActive && !temporarilyUnavailable;

  /// True ak zostatok je pod minimálnym množstvom.
  bool get isLowStock => mnozstvoNaSklade < minimalneMnozstvo;

  /// Validácia predaja: ak [ibaCeleMnozstva], množstvo musí byť celé číslo.
  bool mozePredat(double pozadovaneMnozstvo) {
    if (pozadovaneMnozstvo <= 0) return false;
    if (!ibaCeleMnozstva) return true;
    return pozadovaneMnozstvo == pozadovaneMnozstvo.roundToDouble();
  }

  /// Farba karty pre UI: fialová = rozšírená cenotvorba, sivá = nedostupná, inak null (štandard).
  Color getKartaColor() {
    if (hasExtendedPricing) return Colors.purple;
    if (!isAvailable) return Colors.grey;
    return Colors.black;
  }

  /// Zaokrúhlenie na 3 desatinné miesta (použitie v biznis logike).
  static double round3(double value) {
    return (value * 1000).round() / 1000;
  }

  /// Vytvorí [SkladovaKarta] z [Product] a voliteľného zoznamu zložiek receptúry.
  factory SkladovaKarta.fromProduct(
    Product product, {
    List<RecepturaPolozka> zlozky = const [],
    bool? ibaCeleMnozstva,
  }) {
    return SkladovaKarta(
      id: product.uniqueId ?? '',
      cislo: product.plu,
      nazov: product.name,
      typ: typKartyFromString(product.cardType),
      mernaJednotka: product.unit,
      mnozstvoNaSklade: product.qty.toDouble(),
      nakupnaCena: product.purchasePrice,
      ibaCeleMnozstva: ibaCeleMnozstva ?? product.ibaCeleMnozstva,
      minimalneMnozstvo: product.minQuantity.toDouble(),
      hasExtendedPricing: product.hasExtendedPricing,
      temporarilyUnavailable: product.temporarilyUnavailable,
      isActive: product.isActive,
      zlozky: zlozky,
    );
  }
}
