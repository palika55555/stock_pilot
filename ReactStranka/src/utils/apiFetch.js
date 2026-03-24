import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders, clearAuth } from './auth'

const STORAGE_KEY = 'stockpilot_auth'

/**
 * Obnoví access token pomocou refresh tokenu.
 * Vráti nový access token alebo null ak refresh zlyhal.
 */
async function tryRefreshToken() {
  const auth = getAuth()
  const refreshToken = auth?.refreshToken
  if (!refreshToken) return null

  try {
    const res = await fetch(`${API_BASE_FOR_CALLS}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    })
    if (!res.ok) return null
    const data = await res.json().catch(() => null)
    if (!data?.accessToken) return null

    // Ulož nové tokeny
    const updated = {
      ...auth,
      token: data.accessToken,
      refreshToken: data.refreshToken ?? refreshToken,
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(updated))
    return data.accessToken
  } catch {
    return null
  }
}

/**
 * Centralizovaný fetch s automatickým Bearer tokenom, refresh logikou a 401 redirectom.
 *
 * Použitie:
 *   const data = await apiFetch('/customers')
 *   const data = await apiFetch('/customers', { method: 'POST', body: JSON.stringify({...}) })
 *
 * Ak token expiruje (401):
 *   1. Pokúsi sa obnoviť pomocou refresh tokenu
 *   2. Ak úspešne, zopakuje pôvodný request
 *   3. Ak neúspešne, odhlási používateľa a presmeruje na /
 *
 * @param {string} path - Cesta relatívne k API_BASE_FOR_CALLS (napr. '/customers')
 * @param {RequestInit} options - Štandardné fetch options (method, body, headers, ...)
 * @returns {Promise<any>} - Parsed JSON response
 * @throws {Error} - Pri sieťovej chybe alebo non-OK odpovedi (okrem 401 ktorý je handlovaný)
 */
export async function apiFetch(path, options = {}) {
  const doRequest = (headers) =>
    fetch(`${API_BASE_FOR_CALLS}${path}`, {
      ...options,
      headers: { ...getAuthHeaders(), ...headers, ...(options.headers || {}) },
    })

  let res = await doRequest({})

  if (res.status === 401) {
    const newToken = await tryRefreshToken()
    if (newToken) {
      // Zopakuj request s novým tokenom
      res = await doRequest({ Authorization: `Bearer ${newToken}` })
    }
    if (res.status === 401) {
      // Refresh zlyhal – odhlás a presmeruj na login
      clearAuth()
      window.location.href = '/'
      return null
    }
  }

  if (!res.ok) {
    const errData = await res.json().catch(() => ({}))
    throw new Error(errData.error || `HTTP ${res.status}`)
  }

  // Pre 204 No Content nevracaj JSON
  if (res.status === 204) return null
  return res.json()
}
