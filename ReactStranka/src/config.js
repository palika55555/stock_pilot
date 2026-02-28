/**
 * API base URL a tajný path prefix (musia zodpovedať backendu).
 * Vite vystavuje len premenné s prefixom VITE_.
 * Vercel: VITE_API_URL = https://backend.stockpilot.sk, VITE_API_PREFIX = sp-9f2a4e1b (alebo vlastný)
 */
export const API_BASE = import.meta.env.VITE_API_URL || 'https://backend.stockpilot.sk';

/** Tajný segment cesty pre API – bez neho backend vráti 404. Hodnota musí byť rovnaká ako API_PATH_PREFIX na serveri. */
export const API_PREFIX = import.meta.env.VITE_API_PREFIX || 'sp-9f2a4e1b';

/** Plná base URL pre volania API (bez koncového lomítka), napr. https://backend.stockpilot.sk/api/sp-9f2a4e1b */
export const API_BASE_FOR_CALLS = `${API_BASE}/api/${API_PREFIX}`;
