import { useState, useEffect, useRef, useCallback } from 'react'
import { useNavigate, useLocation, Outlet } from 'react-router-dom'
import { useNotifications } from '../context/NotificationContext'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders, clearAuth } from '../utils/auth'
import './DashboardLayout.css'

const NAV_ITEMS_USER = [
  { path: '/dashboard', label: 'Prehľad', icon: '◉' },
  { path: '/dashboard/products', label: 'Produkty', icon: '📦' },
  { path: '/dashboard/customers', label: 'Zákazníci', icon: '👥' },
  { path: '/dashboard/warehouses', label: 'Sklady', icon: '🏪' },
  { path: '/dashboard/suppliers', label: 'Dodávatelia', icon: '🚚' },
  { path: '/dashboard/quotes', label: 'Cenové ponuky', icon: '📄' },
  { path: '/dashboard/prijemky', label: 'Príjemky', icon: '📥' },
  { path: '/dashboard/vydajky', label: 'Výdajky', icon: '📤' },
  { path: '/dashboard/receptury', label: 'Receptúry', icon: '📋' },
  { path: '/dashboard/vyroba-prikazy', label: 'Výrobné príkazy', icon: '🏭' },
  { path: '/dashboard/transporty', label: 'Transporty', icon: '🚗' },
  { path: '/dashboard/production', label: 'Výrobné šarže', icon: '📊' },
  { path: '/dashboard/scan', label: 'Skenovať', icon: '📷' },
]

// Admin (a db_owner) vidí všetky moduly + extra sekciu Používatelia
const NAV_ITEMS_ADMIN = [
  ...NAV_ITEMS_USER,
  { path: '/dashboard/users', label: 'Používatelia', icon: '👤' },
]

function formatSyncAgo(ts) {
  if (!ts) return ''
  const sec = Math.floor((Date.now() - ts) / 1000)
  if (sec < 60) return 'pred chvíľou'
  if (sec < 3600) return `pred ${Math.floor(sec / 60)} min`
  if (sec < 86400) return `pred ${Math.floor(sec / 3600)} h`
  return `pred ${Math.floor(sec / 86400)} d`
}

export default function DashboardLayout() {
  const navigate = useNavigate()
  const location = useLocation()
  const { unreadCount, last5, markAllAsRead, refresh: refreshNotifications } = useNotifications()
  const [auth, setAuth] = useState(null)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [sidebarOpenMobile, setSidebarOpenMobile] = useState(false)
  const [notifOpen, setNotifOpen] = useState(false)
  const [syncStatus, setSyncStatus] = useState({ last_sync_at: 0, loading: false })
  const notifRef = useRef(null)
  const lastSyncCheckRef = useRef(0)

  useEffect(() => {
    const a = getAuth()
    setAuth(a)
  }, [])

  const doSyncCheck = useCallback((authObj, { force = false } = {}) => {
    if (!authObj?.token) return
    const now = Date.now()
    // Cooldown 30s – zabrání duplicitným requestom pri re-renderoch
    if (!force && now - lastSyncCheckRef.current < 30_000) return
    lastSyncCheckRef.current = now
    const headers = getAuthHeaders(authObj)
    setSyncStatus((s) => ({ ...s, loading: true }))
    fetch(`${API_BASE_FOR_CALLS}/sync/check`, { headers })
      .then((r) => {
        if (r.status === 401) { navigate('/', { replace: true }); return {} }
        return r.ok ? r.json() : {}
      })
      .then((d) => d && Object.keys(d).length && setSyncStatus({ last_sync_at: d.last_sync_at ?? 0, loading: false }))
      .catch(() => setSyncStatus((s) => ({ ...s, loading: false })))
  }, [navigate])

  useEffect(() => {
    if (!auth?.token) return
    doSyncCheck(auth)
  }, [auth, doSyncCheck])

  useEffect(() => {
    function close(e) {
      if (notifRef.current && !notifRef.current.contains(e.target)) setNotifOpen(false)
    }
    if (notifOpen) {
      document.addEventListener('click', close)
      return () => document.removeEventListener('click', close)
    }
  }, [notifOpen])

  const handleSyncClick = () => {
    // Force sync/check + obnov notifikácie (products fetch s force=true)
    doSyncCheck(auth, { force: true })
    refreshNotifications({ force: true })
  }

  const handleLogout = () => {
    clearAuth()
    navigate('/', { replace: true })
  }

  if (!auth) return null

  const pathname = location.pathname
  const syncTs = syncStatus.last_sync_at
  const syncAgoMin = syncTs ? (Date.now() - syncTs) / 60000 : 999
  const syncState = syncStatus.loading ? 'syncing' : syncAgoMin < 5 ? 'ok' : syncAgoMin < 30 ? 'warn' : 'error'

  const isAdmin = auth.user?.role === 'admin' || auth.user?.role === 'db_owner'

  return (
    <div
      className={`dashboard-layout ${isAdmin ? 'dashboard-layout--admin' : ''} ${sidebarCollapsed ? 'dashboard-layout--sidebar-collapsed' : ''} ${sidebarOpenMobile ? 'dashboard-layout--sidebar-open' : ''}`}
    >
      <div className="dashboard-layout__body">
        <div className="dashboard-sidebar-wrap">
          <aside className="dashboard-sidebar">
            <div className="dashboard-sidebar__logo">
              <a href="/dashboard" className="dashboard-sidebar__logo-link" onClick={(e) => { e.preventDefault(); navigate('/dashboard'); setSidebarOpenMobile(false) }}>
                <span className="dashboard-sidebar__logo-label">STOCK</span>
                <h1 className="dashboard-sidebar__logo-title">PILOT</h1>
              </a>
            </div>
            {isAdmin && (
              <div className="dashboard-sidebar__admin-badge">
                <span className="dashboard-sidebar__admin-badge-icon">⚙</span>
                <span className="dashboard-sidebar__admin-badge-text">Admin panel</span>
              </div>
            )}
            <nav className="dashboard-sidebar__nav">
              {(isAdmin ? NAV_ITEMS_ADMIN : NAV_ITEMS_USER).map((item) => {
                const isActive = item.path === '/dashboard' ? pathname === '/dashboard' : pathname.startsWith(item.path)
                return (
                  <button
                    key={item.path + item.label}
                    type="button"
                    className={`dashboard-sidebar__nav-item ${isActive ? 'dashboard-sidebar__nav-item--active' : ''}`}
                    onClick={() => { navigate(item.path); setSidebarOpenMobile(false) }}
                  >
                    <span className="dashboard-sidebar__nav-icon" aria-hidden="true">{item.icon}</span>
                    <span className="dashboard-sidebar__nav-text">{item.label}</span>
                  </button>
                )
              })}
            </nav>
            <div className="dashboard-sidebar__user">
              <div className="dashboard-sidebar__user-name">{auth.user?.fullName || auth.user?.username || 'Používateľ'}</div>
              <div className="dashboard-sidebar__user-role">{auth.user?.role || 'user'}</div>
            </div>
            <button
              type="button"
              className="dashboard-sidebar__collapse-btn"
              onClick={() => setSidebarCollapsed((c) => !c)}
              aria-label={sidebarCollapsed ? 'Rozbaliť menu' : 'Zbaliť menu'}
            >
              {sidebarCollapsed ? '→' : '←'}
            </button>
          </aside>
        </div>

        <div className="dashboard-layout__main">
          <header className="dashboard-topbar">
            <button
              type="button"
              className="dashboard-topbar__menu-mobile"
              onClick={() => setSidebarOpenMobile((o) => !o)}
              aria-label="Menu"
              style={{ display: 'none', marginRight: '0.5rem' }}
            >
              ☰
            </button>
            <div className="dashboard-topbar__search-wrap">
              <input
                type="search"
                className="dashboard-topbar__search"
                placeholder="Vyhľadať..."
                aria-label="Vyhľadávanie"
              />
            </div>
            <div className="dashboard-topbar__right">
              <button
                type="button"
                className="dashboard-topbar__sync"
                onClick={handleSyncClick}
                disabled={syncStatus.loading}
                title="Posledná synchronizácia"
              >
                <span
                  className={`dashboard-topbar__sync-dot dashboard-topbar__sync-dot--${syncState === 'ok' ? 'green' : syncState === 'syncing' ? 'yellow dashboard-topbar__sync-dot--spinning' : 'red'}`}
                />
                <span>
                  {syncStatus.loading ? 'Synchronizujem...' : syncState === 'ok' ? 'Synchronizované' : syncState === 'warn' ? 'Synchronizované' : 'Nesynchronizované'}
                </span>
                {syncTs && !syncStatus.loading && <span style={{ marginLeft: '0.25rem', opacity: 0.8 }}>{formatSyncAgo(syncTs)}</span>}
              </button>
              <div className="dashboard-topbar__notif-wrap" ref={notifRef}>
                <button
                  type="button"
                  className="dashboard-topbar__notif-btn"
                  onClick={() => setNotifOpen((o) => !o)}
                  aria-label="Notifikácie"
                >
                  🔔
                  {unreadCount > 0 && <span className="dashboard-topbar__notif-badge">{unreadCount > 99 ? '99+' : unreadCount}</span>}
                </button>
                {notifOpen && (
                  <div className="dashboard-topbar__notif-dropdown">
                    <div className="dashboard-topbar__notif-dropdown-header">
                      <h3 className="dashboard-topbar__notif-dropdown-title">Notifikácie</h3>
                      {unreadCount > 0 && (
                        <button type="button" className="dashboard-topbar__logout" onClick={markAllAsRead}>
                          Označiť všetky ako prečítané
                        </button>
                      )}
                    </div>
                    <div className="dashboard-topbar__notif-dropdown-list">
                      {last5.length === 0 ? (
                        <div style={{ padding: '1rem', color: 'var(--text-secondary)', fontSize: '0.875rem' }}>Žiadne notifikácie</div>
                      ) : (
                        last5.map((n) => (
                          <div
                            key={n.id}
                            className={`dashboard-topbar__notif-dropdown-item ${n.read ? '' : 'dashboard-topbar__notif-dropdown-item--unread'}`}
                            onClick={() => { navigate(n.link || '/dashboard'); setNotifOpen(false) }}
                            role="button"
                            tabIndex={0}
                            onKeyDown={(e) => { if (e.key === 'Enter') { navigate(n.link || '/dashboard'); setNotifOpen(false) } }}
                          >
                            <strong>{n.title}</strong>
                            {n.body && <div style={{ fontSize: '0.8125rem', color: 'var(--text-secondary)', marginTop: '0.25rem' }}>{n.body}</div>}
                          </div>
                        ))
                      )}
                    </div>
                    <div className="dashboard-topbar__notif-dropdown-footer">
                      <a href="/dashboard" className="dashboard-topbar__notif-dropdown-link" onClick={(e) => { e.preventDefault(); navigate('/dashboard'); setNotifOpen(false) }}>
                        Zobraziť všetky
                      </a>
                    </div>
                  </div>
                )}
              </div>
              <div className="dashboard-topbar__user-avatar" title={auth.user?.fullName || auth.user?.username}>
                {(auth.user?.fullName || auth.user?.username || 'P').charAt(0).toUpperCase()}
              </div>
              <button type="button" className="dashboard-topbar__logout" onClick={handleLogout}>
                Odhlásiť sa
              </button>
            </div>
          </header>
          <main className="dashboard-layout__content">
            <Outlet />
          </main>
        </div>
      </div>
    </div>
  )
}
