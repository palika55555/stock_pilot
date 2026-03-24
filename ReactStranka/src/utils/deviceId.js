const STORAGE_KEY = 'stockpilot_client_device_id'

/**
 * Stabilné ID prehliadača / profilu – väzba 2FA trust tokenu na zariadenie.
 * Prežije odhlásenie; pri vymazaní úložiska sa vygeneruje nové ID.
 */
export function getOrCreateClientDeviceId() {
  try {
    let id = localStorage.getItem(STORAGE_KEY)
    if (id && id.length >= 8) return id
    id =
      typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
        ? crypto.randomUUID()
        : `w-${Date.now()}-${Math.random().toString(36).slice(2, 14)}`
    localStorage.setItem(STORAGE_KEY, id)
    return id
  } catch {
    return `w-${Date.now()}-${Math.random().toString(36).slice(2, 14)}`
  }
}
