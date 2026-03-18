/// Konfigurácia stratégií riešenia konfliktov – Dart/Flutter strana.
///
/// Zrkadlí backend/sync/syncConfig.js.
/// Používa sa v ConflictResolutionWidget na zobrazenie správneho kontextu
/// a v SyncManager ak chceme lokálne predpočítať stratégiu.
///
/// Stratégie:
///   serverWins  – serverová verzia vyhráva vždy
///   clientWins  – klientská (offline) verzia vyhráva
///   newerWins   – novší timestamp vyhráva
///   fieldMerge  – automatické zlúčenie neprekrývajúcich sa polí
///   manual      – prezentuj používateľovi

enum ConflictStrategy {
  serverWins,
  clientWins,
  newerWins,
  fieldMerge,
  manual,
}

/// Popis stratégie pre UI
extension ConflictStrategyLabel on ConflictStrategy {
  String get label {
    switch (this) {
      case ConflictStrategy.serverWins:  return 'Server vyhráva';
      case ConflictStrategy.clientWins:  return 'Lokálna zmena vyhráva';
      case ConflictStrategy.newerWins:   return 'Novšia verzia vyhráva';
      case ConflictStrategy.fieldMerge:  return 'Automatické zlúčenie';
      case ConflictStrategy.manual:      return 'Manuálne rozhodnutie';
    }
  }

  String get description {
    switch (this) {
      case ConflictStrategy.serverWins:
        return 'Zmena z webu / servera má vždy prednosť. Vaša offline zmena bude zahodená.';
      case ConflictStrategy.clientWins:
        return 'Vaša offline zmena bude aplikovaná na server.';
      case ConflictStrategy.newerWins:
        return 'Zmena s novším časovým razítkom bude zachovaná.';
      case ConflictStrategy.fieldMerge:
        return 'Obe zmeny sú zlúčené – každé pole dostane novšiu hodnotu.';
      case ConflictStrategy.manual:
        return 'Prosím vyberte verziu alebo zadajte hodnotu ručne.';
    }
  }
}

/// Konfigurácia per entitný typ
class EntitySyncConfig {
  final ConflictStrategy defaultStrategy;
  final Map<String, ConflictStrategy> fieldStrategies;

  const EntitySyncConfig({
    required this.defaultStrategy,
    this.fieldStrategies = const {},
  });

  ConflictStrategy strategyFor(String? field) {
    if (field != null && fieldStrategies.containsKey(field)) {
      return fieldStrategies[field]!;
    }
    return defaultStrategy;
  }
}

/// Centrálna konfigurácia – identická s backend/sync/syncConfig.js
class SyncConfig {
  static const ConflictStrategy globalDefault = ConflictStrategy.newerWins;

  static const Map<String, EntitySyncConfig> entities = {
    'product': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.newerWins,
      fieldStrategies: {
        'qty':                         ConflictStrategy.serverWins,
        'price':                       ConflictStrategy.manual,
        'purchase_price':              ConflictStrategy.manual,
        'purchase_price_without_vat':  ConflictStrategy.manual,
        'last_purchase_price':         ConflictStrategy.serverWins,
      },
    ),
    'customer': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.newerWins,
      fieldStrategies: {
        'default_vat_rate': ConflictStrategy.serverWins,
        'is_active':        ConflictStrategy.serverWins,
      },
    ),
    'warehouse': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.serverWins,
    ),
    'supplier': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.newerWins,
      fieldStrategies: {
        'is_active': ConflictStrategy.serverWins,
      },
    ),
    'inbound_receipt': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.serverWins,
      fieldStrategies: {
        'status': ConflictStrategy.serverWins,
      },
    ),
    'stock_out': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.serverWins,
      fieldStrategies: {
        'status': ConflictStrategy.serverWins,
      },
    ),
    'recipe': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.newerWins,
    ),
    'production_order': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.serverWins,
      fieldStrategies: {
        'status':           ConflictStrategy.serverWins,
        'planned_quantity': ConflictStrategy.serverWins,
      },
    ),
    'production_batch': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.serverWins,
      fieldStrategies: {
        'status':            ConflictStrategy.serverWins,
        'quantity_produced': ConflictStrategy.serverWins,
      },
    ),
    'quote': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.newerWins,
      fieldStrategies: {
        'status':      ConflictStrategy.serverWins,
        'total_price': ConflictStrategy.serverWins,
        'valid_until': ConflictStrategy.newerWins,
      },
    ),
    'transport': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.serverWins,
      fieldStrategies: {
        'status': ConflictStrategy.serverWins,
      },
    ),
    'pallet': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.serverWins,
      fieldStrategies: {
        'status': ConflictStrategy.serverWins,
      },
    ),
    'company': EntitySyncConfig(
      defaultStrategy: ConflictStrategy.newerWins,
    ),
  };

  static ConflictStrategy strategyFor(String entityType, {String? field}) {
    final entityCfg = entities[entityType];
    if (entityCfg == null) return globalDefault;
    return entityCfg.strategyFor(field);
  }

  /// Lokalizovaný názov entity pre UI
  static String entityLabel(String entityType) {
    const labels = <String, String>{
      'product':          'Produkt',
      'customer':         'Zákazník',
      'warehouse':        'Sklad',
      'supplier':         'Dodávateľ',
      'inbound_receipt':  'Príjemka',
      'stock_out':        'Výdajka',
      'recipe':           'Receptúra',
      'production_order': 'Výrobný príkaz',
      'production_batch': 'Výrobná šarža',
      'quote':            'Cenová ponuka',
      'transport':        'Preprava',
      'pallet':           'Paleta',
      'company':          'Firma',
    };
    return labels[entityType] ?? entityType;
  }
}
