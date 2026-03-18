/**
 * syncConfig.js – Konfigurácia stratégií riešenia konfliktov pre Stock Pilot.
 *
 * Stratégie:
 *   'server-wins'  – serverová verzia má vždy prednosť, offline zmena sa zahodí
 *   'client-wins'  – offline zmena má prednosť, server sa prepíše
 *   'newer-wins'   – porovná timestamp, novšia zmena vyhráva (default)
 *   'field-merge'  – ak sa polia neprekrývajú, automaticky zlúči obe zmeny
 *   'manual'       – prezentuje konflikt používateľovi na manuálne rozhodnutie
 *
 * Priorita: fields[fieldName] > entities[entityType].default > global.default
 */
const syncConfig = {
  global: {
    default: 'newer-wins',
  },

  entities: {
    product: {
      default: 'newer-wins',
      fields: {
        qty:                    'server-wins',  // Množstvo riadiace skladom vyhráva server (zábraňuje duplicitným pohybom)
        price:                  'manual',       // Cena – vyžaduje ľudské rozhodnutie
        purchase_price:         'manual',
        purchase_price_without_vat: 'manual',
        last_purchase_price:    'server-wins',
      },
    },

    customer: {
      default: 'newer-wins',
      fields: {
        default_vat_rate: 'server-wins',
        is_active:        'server-wins',
      },
    },

    warehouse: {
      default: 'server-wins',
    },

    supplier: {
      default: 'newer-wins',
      fields: {
        is_active: 'server-wins',
      },
    },

    // Príjemky sú finančné doklady – server je autoritatívny zdroj
    inbound_receipt: {
      default: 'server-wins',
      fields: {
        status: 'server-wins',
      },
    },

    stock_out: {
      default: 'server-wins',
      fields: {
        status: 'server-wins',
      },
    },

    recipe: {
      default: 'newer-wins',
    },

    production_order: {
      default: 'server-wins',
      fields: {
        status:           'server-wins',
        planned_quantity: 'server-wins',
      },
    },

    production_batch: {
      default: 'server-wins',
      fields: {
        status:             'server-wins',
        quantity_produced:  'server-wins',
      },
    },

    quote: {
      default: 'newer-wins',
      fields: {
        status:      'server-wins',
        total_price: 'server-wins',
        valid_until: 'newer-wins',
      },
    },

    transport: {
      default: 'server-wins',
      fields: {
        status: 'server-wins',
      },
    },

    pallet: {
      default: 'server-wins',
      fields: {
        status: 'server-wins',
      },
    },

    company: {
      default: 'newer-wins',
    },
  },
};

module.exports = { syncConfig };
