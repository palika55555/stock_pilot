import { useState, useEffect, useRef } from 'react'
import { useNavigate, useLocation, Outlet } from 'react-router-dom'
import { useNotifications } from '../context/NotificationContext'
import { getAuth } from '../utils/auth'
import './DashboardLayout.css'

const NAV_SECTIONS = [
  {
    label: null,
    items: [
      { path: '/dashboard', label: 'Prehľad', icon: '🏠' },
    ],
  },
  {
    label: 'Sklad',
    items: [
      { path: '/dashboard/products', label: 'Produkty', icon: '📦' },
      { path: '/dashboard/warehouses', label: 'Sklady', icon: '🏗️' },
      { path: '/dashboard/prijemky', label: 'Príjemky', icon: '📥' },
      { path: '/dashboard/vydajky', label: 'Výdajky', icon: '📤' },
    ],
  },
  {
    label: 'Obchod',
    items: [
      { path: '/dashboard/customers', label: 'Zákazníci', icon: '👥' },
      { path: '/dashboard/suppliers', label: 'Dodávatelia', icon: '🚚' },
      { path: '/dashboard/quotes', label: 'Cenové ponuky', icon: '📄' },
      { path: '/dashboard/transporty', label: 'Doprava', icon: '🗺️' },
    ],
  },
  {
    label: 'Výroba',
    items: [
      { path: '/dashboard/receptury', label: 'Receptúry', icon: '📋' },
      { path: '/dashboard/vyroba-prikazy', label: 'Výrobné príkazy', icon: '🏭' },
      { path: '/dashboard/production', label: 'Výrobné šarže', icon: '🔢' },
    ],
  },
  {
    label: 'Nástroje',
    items: [
      { path: '/dashboard/scan', label: 'Skenovať', icon: '📷' },
      { path: '/dashboard/security-2fa', label: 'Security / 2FA', icon: '🔐' },
    ],
  },
]

const NAV_SECTIONS_ADMIN = [
  ...NAV_SECTIONS,
  {
    label: 'Správa',
    items: [
      { path: '/dashboard/users', label: 'Používatelia', icon: '👤' },
      { path: '/dashboard/system-status', label: 'System Status', icon: '🖥️' },
    ],
  },
]

// flat lists pre spätnú kompatibilitu
const NAV_ITEMS_USER = NAV_SECTIONS.flatMap(s => s.items)
const NAV_ITEMS_ADMIN = NAV_SECTIONS_ADMIN.flatMap(s => s.items)

export default function DashboardLayout() {
  const navigate = useNavigate()
  const location = useLocation()
  const { unreadCount, last5, markAllAsRead } = useNotifications()
  const [auth, setAuth] = useState(null)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [sidebarOpenMobile, setSidebarOpenMobile] = useState(false)
  const [moreSheetOpen, setMoreSheetOpen] = useState(false)
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
    navigate('/goodbye', { replace: true })
  }

  if (!auth) return null

  const pathname = location.pathname

  const isAdmin = auth.user?.role === 'admin' || auth.user?.role === 'db_owner'
  const isDbOwner = auth.user?.role === 'db_owner'

  const activeSections = isDbOwner
    ? NAV_SECTIONS_ADMIN
    : isAdmin
      ? NAV_SECTIONS_ADMIN.map(s => s.label === 'Správa' ? { ...s, items: s.items.filter(i => i.path !== '/dashboard/system-status') } : s)
      : NAV_SECTIONS

  const BOTTOM_NAV = [
    { path: '/dashboard', label: 'Prehľad', icon: '🏠' },
    { path: '/dashboard/products', label: 'Produkty', icon: '📦' },
    { path: '/dashboard/customers', label: 'Zákazníci', icon: '👥' },
    { path: '/dashboard/warehouses', label: 'Sklady', icon: '🏗️' },
  ]

  return (
    <div
      className={`dashboard-layout ${isAdmin ? 'dashboard-layout--admin' : ''} ${sidebarCollapsed ? 'dashboard-layout--sidebar-collapsed' : ''} ${sidebarOpenMobile ? 'dashboard-layout--sidebar-open' : ''}`}
    >
      <div className="dashboard-layout__body">
        <div className="dashboard-sidebar-wrap">
          {sidebarOpenMobile && (
            <div className="dashboard-sidebar-backdrop" onClick={() => setSidebarOpenMobile(false)} aria-hidden="true" />
          )}
          <aside className="dashboard-sidebar">
            <div className="dashboard-sidebar__mobile-header">
              <span className="dashboard-sidebar__logo-label" style={{ fontSize: '0.75rem', letterSpacing: '0.15em' }}>STOCK <strong style={{ color: 'var(--accent-gold)' }}>PILOT</strong></span>
              <button
                type="button"
                className="dashboard-sidebar__mobile-close"
                onClick={() => setSidebarOpenMobile(false)}
                aria-label="Zavrieť menu"
              >✕</button>
            </div>
            <div className="dashboard-sidebar__logo dashboard-sidebar__logo--desktop">
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
              {activeSections.map((section, si) => (
                <div key={si} className="dashboard-sidebar__section">
                  {section.label && (
                    <div className="dashboard-sidebar__section-label">{section.label}</div>
                  )}
                  {section.items.map((item) => {
                    const isActive = item.path === '/dashboard' ? pathname === '/dashboard' : pathname.startsWith(item.path)
                    return (
                      <button
                        key={item.path + item.label}
                        type="button"
                        title={item.label}
                        className={`dashboard-sidebar__nav-item ${isActive ? 'dashboard-sidebar__nav-item--active' : ''}`}
                        onClick={() => { if (!isActive) navigate(item.path); setSidebarOpenMobile(false) }}
                      >
                        <span className="dashboard-sidebar__nav-icon" aria-hidden="true">{item.icon}</span>
                        <span className="dashboard-sidebar__nav-text">{item.label}</span>
                      </button>
                    )
                  })}
                </div>
              ))}
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

      {/* ─── Mobile bottom nav ─── */}
      <nav className="dashboard-bottom-nav">
        {BOTTOM_NAV.map((item) => {
          const isActive = item.path === '/dashboard' ? pathname === '/dashboard' : pathname.startsWith(item.path)
          return (
            <button
              key={item.path}
              type="button"
              className={`dashboard-bottom-nav__item ${isActive ? 'dashboard-bottom-nav__item--active' : ''}`}
              onClick={() => { if (!isActive) navigate(item.path); setMoreSheetOpen(false) }}
            >
              <span className="dashboard-bottom-nav__icon">{item.icon}</span>
              <span className="dashboard-bottom-nav__label">{item.label}</span>
            </button>
          )
        })}
        <button
          type="button"
          className={`dashboard-bottom-nav__item ${moreSheetOpen ? 'dashboard-bottom-nav__item--active' : ''}`}
          onClick={() => setMoreSheetOpen((o) => !o)}
        >
          <span className="dashboard-bottom-nav__icon">☰</span>
          <span className="dashboard-bottom-nav__label">Viac</span>
        </button>
      </nav>

      {/* ─── Mobile "Viac" bottom sheet ─── */}
      {moreSheetOpen && (
        <div className="more-sheet-backdrop" onClick={() => setMoreSheetOpen(false)} aria-hidden="true" />
      )}
      <div className={`more-sheet ${moreSheetOpen ? 'more-sheet--open' : ''}`}>
        <div className="more-sheet__handle" onClick={() => setMoreSheetOpen(false)} />
        <div className="more-sheet__header">
          <span className="more-sheet__title">Navigácia</span>
          <button type="button" className="more-sheet__close" onClick={() => setMoreSheetOpen(false)} aria-label="Zavrieť">✕</button>
        </div>
        <div className="more-sheet__body">
          {activeSections.map((section, si) => (
            <div key={si} className="more-sheet__section">
              {section.label && <div className="more-sheet__section-label">{section.label}</div>}
              <div className="more-sheet__grid">
                {section.items.map((item) => {
                  const isActive = item.path === '/dashboard' ? pathname === '/dashboard' : pathname.startsWith(item.path)
                  return (
                    <button
                      key={item.path}
                      type="button"
                      className={`more-sheet__item ${isActive ? 'more-sheet__item--active' : ''}`}
                      onClick={() => { if (!isActive) navigate(item.path); setMoreSheetOpen(false) }}
                    >
                      <span className="more-sheet__item-icon">{item.icon}</span>
                      <span className="more-sheet__item-label">{item.label}</span>
                    </button>
                  )
                })}
              </div>
            </div>
          ))}
          <button type="button" className="more-sheet__logout" onClick={handleLogout}>
            🚪 Odhlásiť sa
          </button>
        </div>
      </div>
    </div>
  )
}
