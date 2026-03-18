/**
 * conflictResolution.js – Generický engine na detekciu a riešenie konfliktov pri sync.
 *
 * Funguje pre akýkoľvek entityType bez potreby písať špecifickú logiku per typ.
 * Stratégie sa preberajú zo syncConfig (global → entity default → per-field).
 */

class ConflictResolutionEngine {
  /**
   * @param {import('./syncConfig').syncConfig} config
   */
  constructor(config) {
    this.config = config || {};
    this.globalDefault = config?.global?.default || 'newer-wins';
  }

  /**
   * Analyzuje a rieši konflikt medzi klientskou a serverovou zmenou.
   *
   * @param {object} params
   * @param {string} params.entityType       – napr. 'product', 'customer'
   * @param {string} params.entityId         – ID záznamu
   * @param {object} params.clientChange     – { fieldChanges, timestamp, clientVersion }
   * @param {object} params.serverState      – { fieldChanges (posledné server zmeny), version, updatedAt }
   *
   * @returns {{
   *   hasConflict:       boolean,
   *   strategy:          string,
   *   result:            'server-wins'|'client-wins'|'field-merge'|'manual'|null,
   *   mergedFields:      object|null,
   *   conflictingFields: string[],
   * }}
   */
  resolve({ entityType, entityId, clientChange, serverState }) {
    const clientFields  = clientChange?.fieldChanges  || {};
    const serverFields  = serverState?.fieldChanges   || {};

    // Polia zmenené oboma stranami súčasne
    const conflictingFields = this._getConflictingFields(clientFields, serverFields);

    // Žiadny prekryv → automatický field-merge (bezkonfliktné zlúčenie)
    if (conflictingFields.length === 0) {
      return {
        hasConflict:       false,
        strategy:          'field-merge',
        result:            'field-merge',
        mergedFields:      { ...serverFields, ...clientFields },
        conflictingFields: [],
      };
    }

    // Urči stratégiu (najšpecifickejšia vyhráva)
    const strategy = this._pickStrategy(entityType, conflictingFields);

    switch (strategy) {
      case 'server-wins':
        return { hasConflict: true, strategy, result: 'server-wins', mergedFields: null, conflictingFields };

      case 'client-wins':
        return { hasConflict: true, strategy, result: 'client-wins', mergedFields: null, conflictingFields };

      case 'newer-wins': {
        const clientTs = new Date(clientChange.timestamp || 0).getTime();
        const serverTs = new Date(serverState.updatedAt   || 0).getTime();
        const result   = clientTs >= serverTs ? 'client-wins' : 'server-wins';
        return { hasConflict: true, strategy, result, mergedFields: null, conflictingFields };
      }

      case 'field-merge': {
        // Pre každé konfliktné pole použi newer-wins; nekonflikntné polia z oboch strán zlúč
        const merged = { ...serverFields };
        for (const field of Object.keys(clientFields)) {
          if (!conflictingFields.includes(field)) {
            // Nekonflikntné pole – client vždy zapíše
            merged[field] = clientFields[field];
          } else {
            // Konfliktné pole – newer-wins per-field
            const clientTs = new Date(clientChange.timestamp || 0).getTime();
            const serverTs = new Date(serverState.updatedAt  || 0).getTime();
            if (clientTs >= serverTs) merged[field] = clientFields[field];
          }
        }
        return { hasConflict: true, strategy, result: 'field-merge', mergedFields: merged, conflictingFields };
      }

      case 'manual':
      default:
        return { hasConflict: true, strategy: 'manual', result: 'manual', mergedFields: null, conflictingFields };
    }
  }

  // -----------------------------------------------------------------------
  // Interné pomocné metódy
  // -----------------------------------------------------------------------

  /** Vráti polia prítomné v oboch fieldChanges objektoch (skutočný konflikt). */
  _getConflictingFields(clientFields, serverFields) {
    const clientKeys = new Set(Object.keys(clientFields));
    return Object.keys(serverFields).filter((k) => clientKeys.has(k));
  }

  /**
   * Vyberie stratégiu s prioritou:
   *  1. Per-field stratégia (ak iba 1 konfliktné pole)
   *  2. Per-entity default
   *  3. Global default
   */
  _pickStrategy(entityType, conflictingFields) {
    const entityCfg = this.config.entities?.[entityType];

    // Per-field (len keď je jediný konfliktný field)
    if (entityCfg?.fields && conflictingFields.length === 1) {
      const fieldStrategy = entityCfg.fields[conflictingFields[0]];
      if (fieldStrategy) return fieldStrategy;
    }

    // Ak má viacero konfliktných polí rôzne stratégie → použi najprísnejšiu
    if (entityCfg?.fields && conflictingFields.length > 1) {
      const strategies = conflictingFields
        .map((f) => entityCfg.fields?.[f])
        .filter(Boolean);
      if (strategies.includes('manual'))       return 'manual';
      if (strategies.includes('server-wins'))  return 'server-wins';
      if (strategies.includes('client-wins'))  return 'client-wins';
      if (strategies.includes('newer-wins'))   return 'newer-wins';
      if (strategies.includes('field-merge'))  return 'field-merge';
    }

    return entityCfg?.default || this.globalDefault;
  }
}

module.exports = { ConflictResolutionEngine };
