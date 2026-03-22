import { useState, useEffect, useRef } from 'react'
import { useNavigate, useLocation, Outlet } from 'react-router-dom'
import { useNotifications } from '../context/NotificationContext'
import { getAuth, clearAuth } from '../utils/auth'
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
  { path: '/dashboard/transporty', label: 'Doprava', icon: '🚚' },
  { path: '/dashboard/production', label: 'Výrobné šarže', icon: '📊' },
  { path: '/dashboard/scan', label: 'Skenovať', icon: '📷' },
]

// Admin (a db_owner) vidí všetky moduly + extra sekcie
const NAV_ITEMS_ADMIN = [
  ...NAV_ITEMS_USER,
  { path: '/dashboard/users', label: 'Používatelia', icon: '👤' },
  { path: '/dashboard/system-status', label: 'System Status', icon: '🖥' },
]

export default function DashboardLayout() {
  const navigate = useNavigate()
  const location = useLocation()
  const { unreadCount, last5, markAllAsRead } = useNotifications()
  const [auth, setAuth] = useState(null)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [sidebarOpenMobile, setSidebarOpenMobile] = useState(false)
  const [notifOpen, setNotifOpen] = useState(false)
  const notifRef = useRef(null)

  useEffect(() => {
    const a = getAuth()
    setAuth(a)
  }, [])

  useEffect(() => {
    function close(e) {
      if (notifRef.current && !notifRef.current.contains(e.target)) setNotifOpen(false)
    }
    if (notifOpen) {
      document.addEventListener('click', close)
      return () => document.removeEventListener('click', close)
    }
  }, [notifOpen])

  const handleLogout = () => {
    clearAuth()
    navigate('/', { replace: true })
  }

  if (!auth) return null

  const pathname = location.pathname

  const isAdmin = auth.user?.role === 'admin' || auth.user?.role === 'db_owner'
  const isDbOwner = auth.user?.role === 'db_owner'

  return (
    <div
      className={`dashboard-layout ${isAdmin ? 'dashboard-layout--admin' : ''} ${sidebarCollapsed ? 'dashboard-layout--sidebar-collapsed' : ''} ${sidebarOpenMobile ? 'dashboard-layout--sidebar-open' : ''}`}
    >
      <div className="dashboard-layout__body">
        <div className="dashboard-sidebar-wrap">
          <aside className="dashboard-sidebar">
            <div className="dashboard-sidebar__logo">
              <a href="/dashboard" className="dashboard-sidebar__logo-link" onClick={(e) => { e.preventDefault(); if (pathname !== '/dashboard') navigate('/dashboard'); setSidebarOpenMobile(false) }}>
                <span className="dashboard-sidebar__logo-label">STOCK</span>
                <h1 className="dashboard-sidebar__logo-title">PILOT</h1>
              </a>
            </div>
            {isAdmin && (
              <div className="dashboard-sidebar__admin-badge">
                <span className="dashboard-sidebar__admin-badge-icon">⚙</span>
                <span className="dashboard-sidebar__admin-badge-text">{isDbOwner ? 'DB Owner' : 'Admin panel'}</span>
              </div>
            )}
            <nav className="dashboard-sidebar__nav">
              {(isDbOwner ? NAV_ITEMS_ADMIN : isAdmin ? NAV_ITEMS_ADMIN.filter(i => i.path !== '/dashboard/system-status') : NAV_ITEMS_USER).map((item) => {
                const isActive = item.path === '/dashboard' ? pathname === '/dashboard' : pathname.startsWith(item.path)
                return (
                  <button
                    key={item.path + item.label}
                    type="button"
                    className={`dashboard-sidebar__nav-item ${isActive ? 'dashboard-sidebar__nav-item--active' : ''}`}
                    onClick={() => { if (!isActive) navigate(item.path); setSidebarOpenMobile(false) }}
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
