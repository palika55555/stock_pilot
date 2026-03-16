import { createContext, useContext, useState, useCallback, useEffect, useRef } from 'react'
import { API_BASE_FOR_CALLS } from '../config'

const NOTIFICATION_STORAGE_KEY = 'stockpilot_notifications'
const MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000 // 7 days

export const NotificationContext = createContext({
  notifications: [],
  unreadCount: 0,
  markAsRead: () => {},
  markAllAsRead: () => {},
  refresh: () => {},
})

function getStorageKey(userId) {
  return `${NOTIFICATION_STORAGE_KEY}_${userId || 'anon'}`
}

function loadStored(userId) {
  try {
    const raw = localStorage.getItem(getStorageKey(userId))
    if (!raw) return []
    const list = JSON.parse(raw)
    const now = Date.now()
    return list.filter((n) => n.createdAt && now - n.createdAt < MAX_AGE_MS)
  } catch {
    return []
  }
}

function saveStored(userId, list) {
  try {
    localStorage.setItem(getStorageKey(userId), JSON.stringify(list))
  } catch (_) {}
}

export function NotificationProvider({ children, auth }) {
  const [notifications, setNotifications] = useState([])
  const userId = auth?.user?.id || auth?.user?.username || null

  const load = useCallback(() => {
    const stored = loadStored(userId)
    setNotifications(stored)
  }, [userId])

  useEffect(() => {
    load()
  }, [load])

  // Auto-fetch pri prvom moute s tokenom (1x, cooldown bráni ďalším)
  useEffect(() => {
    if (auth?.token) addFromApi(auth.token)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [auth?.token])

  // Cooldown: zabrání opakovanému fetch pri rýchlej navigácii (min. 30s medzi volaniami)
  const lastFetchRef = useRef(0)

  const addFromApi = useCallback(
    async (token, { force = false } = {}) => {
      if (!token) return
      const now = Date.now()
      if (!force && now - lastFetchRef.current < 30_000) return
      lastFetchRef.current = now

      const headers = { Authorization: token.startsWith('Bearer ') ? token : `Bearer ${token}` }
      const newItems = []
      try {
        // Len products – stats a sync/check fetchuje DashboardLayout samostatne
        const productsRes = await fetch(`${API_BASE_FOR_CALLS}/products`, { headers }).then((r) => (r.ok ? r.json() : []))
        if (Array.isArray(productsRes)) {
          const low = productsRes.filter((p) => (p.qty ?? 0) < 5)
          low.slice(0, 10).forEach((p) => {
            newItems.push({
              id: `low-${String(p.unique_id)}`,
              type: 'critical',
              title: `${p.name || p.unique_id} – nízke zásoby`,
              body: `Zostatok: ${p.qty ?? 0} ks (min: 5)`,
              createdAt: now,
              read: false,
              link: `/dashboard/products/${encodeURIComponent(p.unique_id)}`,
            })
          })
        }
        const stored = loadStored(userId)
        const byId = new Map(stored.map((n) => [n.id, n]))
        newItems.forEach((n) => {
          const existing = byId.get(n.id)
          byId.set(n.id, existing ? { ...n, read: existing.read } : n)
        })
        const merged = Array.from(byId.values()).sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0))
        const trimmed = merged.slice(0, 50)
        const filtered = trimmed.filter((n) => n.createdAt && now - n.createdAt < MAX_AGE_MS)
        setNotifications(filtered)
        saveStored(userId, filtered)
      } catch (_) {
        load()
      }
    },
    [userId, load]
  )

  const refresh = useCallback(({ force = false } = {}) => {
    load()
    if (auth?.token) addFromApi(auth.token, { force })
  }, [auth?.token, load, addFromApi])

  const markAsRead = useCallback(
    (id) => {
      setNotifications((prev) => {
        const next = prev.map((n) => (n.id === id ? { ...n, read: true } : n))
        saveStored(userId, next)
        return next
      })
    },
    [userId]
  )

  const markAllAsRead = useCallback(() => {
    setNotifications((prev) => {
      const next = prev.map((n) => ({ ...n, read: true }))
      saveStored(userId, next)
      return next
    })
  }, [userId])

  const unreadCount = notifications.filter((n) => !n.read).length
  const last5 = notifications.slice(0, 5)

  const value = {
    notifications,
    unreadCount,
    last5,
    markAsRead,
    markAllAsRead,
    refresh,
    addFromApi,
  }

  return <NotificationContext.Provider value={value}>{children}</NotificationContext.Provider>
}

export function useNotifications() {
  const ctx = useContext(NotificationContext)
  if (!ctx) throw new Error('useNotifications must be used within NotificationProvider')
  return ctx
}
