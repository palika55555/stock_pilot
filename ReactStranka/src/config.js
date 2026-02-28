/**
 * API base URL z premenných prostredia.
 * Vite vystavuje do klientskej aplikácie len premenné s prefixom VITE_.
 * Na Verceli nastav v projekte: Settings → Environment Variables → VITE_API_URL = https://backend.stockpilot.sk
 */
export const API_BASE = import.meta.env.VITE_API_URL || 'https://backend.stockpilot.sk';
