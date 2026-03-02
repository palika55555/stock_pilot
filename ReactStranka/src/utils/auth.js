const STORAGE_KEY = 'stockpilot_auth'

/**
 * Get parsed auth from localStorage.
 * Expected shape: { user, token, refreshToken }
 */
export function getAuth() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

/**
 * Get access token only (for API calls).
 */
export function getToken() {
  const auth = getAuth()
  return auth?.token ?? null
}

/**
 * Headers object for authenticated requests. Always uses Bearer prefix.
 * Returns {} if no token (caller should handle unauthenticated state).
 */
export function getAuthHeaders(auth = null) {
  const a = auth ?? getAuth()
  const t = a?.token
  if (!t) return {}
  return {
    Authorization: t.startsWith('Bearer ') ? t : `Bearer ${t}`,
    'Content-Type': 'application/json',
  }
}

export function clearAuth() {
  localStorage.removeItem(STORAGE_KEY)
}
