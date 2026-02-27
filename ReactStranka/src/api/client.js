/**
 * Centrálny API klient pre backend.stockpilot.sk.
 * Bezpečnostná hlavička x-stockpilot-key (malé písmená pre Cloudflare WAF) sa pridáva
 * len k požiadavkám smerujúcim na doménu stockpilot.sk; hodnota z VITE_BACKEND_SECRET_KEY.
 */
const API_BASE = import.meta.env.VITE_API_URL || 'https://backend.stockpilot.sk'
const API_KEY = import.meta.env.VITE_BACKEND_SECRET_KEY || ''

const isStockPilotDomain = () => API_BASE.includes('stockpilot.sk')

/** Základné hlavičky. x-stockpilot-key len pre stockpilot.sk, aby sa kľúč neposielal tretím stranám. */
export function getApiHeaders(extra = {}) {
  return {
    'Content-Type': 'application/json',
    ...(isStockPilotDomain() && API_KEY ? { 'x-stockpilot-key': API_KEY } : {}),
    ...extra,
  }
}

/** GET požiadavka na API. */
export async function apiGet(path, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'GET',
    headers: getApiHeaders(options.headers),
    credentials: 'include',
    ...options,
  })
  return res
}

/** POST požiadavka na API. */
export async function apiPost(path, body, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: getApiHeaders(options.headers),
    credentials: 'include',
    body: typeof body === 'string' ? body : JSON.stringify(body ?? {}),
    ...options,
  })
  return res
}

/** PUT požiadavka na API. */
export async function apiPut(path, body, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'PUT',
    headers: getApiHeaders(options.headers),
    credentials: 'include',
    body: typeof body === 'string' ? body : JSON.stringify(body ?? {}),
    ...options,
  })
  return res
}

export { API_BASE }
