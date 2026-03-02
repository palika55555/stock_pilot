import { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { useNotifications } from '../context/NotificationContext'
import './DashboardPage.css'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'

function formatCurrency(value) {
  const n = Number(value)
  if (Number.isNaN(n)) return '0,00 €'
  return new Intl.NumberFormat('sk-SK', {
    style: 'currency',
    currency: 'EUR',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(n)
}

function formatAgo(ts) {
  if (!ts) return ''
  const sec = Math.floor((Date.now() - new Date(ts).getTime()) / 1000)
  if (sec < 60) return 'pred chvíľou'
  if (sec < 3600) return `pred ${Math.floor(sec / 60)} min`
  if (sec < 86400) return `pred ${Math.floor(sec / 3600)} h`
  return `pred ${Math.floor(sec / 86400)} d`
}

// Count-up animation for KPI value
function AnimatedNumber({ value, duration = 800, formatter = (v) => v }) {
  const [display, setDisplay] = useState(0)
  const prevRef = useRef(value)
  useEffect(() => {
    const start = prevRef.current
    prevRef.current = value
    const startTime = performance.now()
    const raf = (now) => {
      const elapsed = now - startTime
      const t = Math.min(elapsed / duration, 1)
      const eased = 1 - (1 - t) * (1 - t)
      setDisplay(Math.round(start + (value - start) * eased))
      if (t < 1) requestAnimationFrame(raf)
    }
    requestAnimationFrame(raf)
  }, [value, duration])
  return formatter(display)
}

const NOTIF_TABS = [
  { id: 'all', label: 'Všetky' },
  { id: 'stock', label: 'Zásoby' },
  { id: 'sync', label: 'Sync' },
  { id: 'system', label: 'Systém' },
]

export default function DashboardPage() {
  const navigate = useNavigate()
  const { notifications, markAsRead, refresh } = useNotifications()
  const [auth, setAuth] = useState(null)
  const [stats, setStats] = useState({
    products_count: 0,
    customers_count: 0,
    total_sales: 0,
    low_stock_count: 0,
    products_trend_week: 0,
    customers_trend_week: 0,
    sales_trend_week: 0,
    last_sync_at: 0,
  })
  const [batches, setBatches] = useState([])
  const [loading, setLoading] = useState(true)
  const [notifTab, setNotifTab] = useState('all')
  const [syncing, setSyncing] = useState(false)
  const notificationsRef = useRef(null)

  useEffect(() => {
    setAuth(getAuth())
  }, [])

  useEffect(() => {
    if (!auth?.token) return
    let cancelled = false
    const headers = getAuthHeaders(auth)
    Promise.all([
      fetch(`${API_BASE_FOR_CALLS}/dashboard/stats`, { headers }).then((r) => { if (r.status === 401) { navigate('/', { replace: true }); return {} }; return r.ok ? r.json() : {} }),
      fetch(`${API_BASE_FOR_CALLS}/batches?limit=10`, { headers }).then((r) => { if (r.status === 401) { navigate('/', { replace: true }); return [] }; return r.ok ? r.json() : [] }),
    ])
      .then(([data, batchList]) => {
        if (!cancelled) {
          setStats((s) => ({
            ...s,
            products_count: data.products_count ?? data.products ?? 0,
            customers_count: data.customers_count ?? data.customers ?? 0,
            total_sales: data.total_sales ?? data.revenue ?? 0,
            low_stock_count: data.low_stock_count ?? 0,
            products_trend_week: data.products_trend_week ?? 0,
            customers_trend_week: data.customers_trend_week ?? 0,
            sales_trend_week: data.sales_trend_week ?? 0,
            last_sync_at: data.last_sync_at ?? 0,
          }))
          setBatches(Array.isArray(batchList) ? batchList : [])
        }
      })
      .catch(() => {})
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [auth, navigate])

  useEffect(() => {
    refresh()
  }, [refresh])

  const scrollToNotifications = () => {
    notificationsRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  const handleSync = () => {
    setSyncing(true)
    refresh()
    setTimeout(() => setSyncing(false), 1500)
  }

  const filteredNotifs = notifTab === 'all'
    ? notifications
    : notifications.filter((n) => (n.type && n.category === notifTab) || (notifTab === 'stock' && n.title?.includes('zásoby')) || (notifTab === 'sync' && n.title?.includes('Synchronizácia')) || (notifTab === 'system' && n.title?.includes('Systém')))
  const displayNotifs = (notifTab === 'all' ? notifications : filteredNotifs).slice(0, 10)

  const trendClass = (v) => (v > 0 ? 'positive' : v < 0 ? 'negative' : 'neutral')
  const trendLabel = (v) => (v > 0 ? `↑ ${v}%` : v < 0 ? `↓ ${Math.abs(v)}%` : '→ 0%')

  if (!auth) return null

  return (
    <div className="dashboard-overview">
      {loading ? (
        <div className="dashboard-overview__skeleton">
          <div className="dashboard-overview__skeleton-row dashboard-overview__skeleton-kpis" />
          <div className="dashboard-overview__skeleton-row dashboard-overview__skeleton-main" />
        </div>
      ) : (
        <>
          <section className="dashboard-kpis" aria-label="KPI karty">
            <div
              className="dashboard-kpi-card dashboard-kpi-card--gold"
              onClick={() => navigate('/dashboard/products')}
              onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); navigate('/dashboard/products') } }}
              role="button"
              tabIndex={0}
            >
              <div className="dashboard-kpi-card__head">
                <span className="dashboard-kpi-card__icon">📦</span>
                <span className="dashboard-kpi-card__title">Produkty</span>
                <span className={`dashboard-kpi-card__trend dashboard-kpi-card__trend--${trendClass(stats.products_trend_week)}`}>
                  {trendLabel(stats.products_trend_week)}
                </span>
              </div>
              <div className="dashboard-kpi-card__value">
                <AnimatedNumber value={stats.products_count} />
              </div>
              <div className="dashboard-kpi-card__footer">vs minulý týždeň: {stats.products_trend_week >= 0 ? '+' : ''}{stats.products_trend_week}%</div>
            </div>

            <div
              className="dashboard-kpi-card dashboard-kpi-card--blue"
              onClick={() => navigate('/dashboard/customers')}
              onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); navigate('/dashboard/customers') } }}
              role="button"
              tabIndex={0}
            >
              <div className="dashboard-kpi-card__head">
                <span className="dashboard-kpi-card__icon">👥</span>
                <span className="dashboard-kpi-card__title">Zákazníci</span>
                <span className={`dashboard-kpi-card__trend dashboard-kpi-card__trend--${trendClass(stats.customers_trend_week)}`}>
                  {trendLabel(stats.customers_trend_week)}
                </span>
              </div>
              <div className="dashboard-kpi-card__value">
                <AnimatedNumber value={stats.customers_count} />
              </div>
              <div className="dashboard-kpi-card__footer">noví tento týždeň: {stats.customers_trend_week >= 0 ? '+' : ''}{stats.customers_trend_week}</div>
            </div>

            <div className="dashboard-kpi-card dashboard-kpi-card--green">
              <div className="dashboard-kpi-card__head">
                <span className="dashboard-kpi-card__icon">💰</span>
                <span className="dashboard-kpi-card__title">Tržby</span>
                <span className={`dashboard-kpi-card__trend dashboard-kpi-card__trend--${trendClass(stats.sales_trend_week)}`}>
                  {trendLabel(stats.sales_trend_week)}
                </span>
              </div>
              <div className="dashboard-kpi-card__value dashboard-kpi-card__value--currency">
                {formatCurrency(stats.total_sales)}
              </div>
              <div className="dashboard-kpi-card__footer">vs minulý týždeň: {trendLabel(stats.sales_trend_week)}</div>
            </div>

            <div
              className={`dashboard-kpi-card dashboard-kpi-card--orange ${stats.low_stock_count > 0 ? 'dashboard-kpi-card--pulse' : ''}`}
              onClick={scrollToNotifications}
              onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); scrollToNotifications() } }}
              role="button"
              tabIndex={0}
            >
              <div className="dashboard-kpi-card__head">
                <span className="dashboard-kpi-card__icon">⚠️</span>
                <span className="dashboard-kpi-card__title">Skladové upozornenia</span>
                <span className={`dashboard-kpi-card__trend dashboard-kpi-card__trend--neutral`}>→</span>
              </div>
              <div className="dashboard-kpi-card__value">
                <AnimatedNumber value={stats.low_stock_count} />
              </div>
              <div className="dashboard-kpi-card__footer">produktov pod minimum</div>
            </div>
          </section>

          <div className="dashboard-overview__main">
            <section className="dashboard-activity">
              <h3 className="dashboard-activity__title">Posledná aktivita</h3>
              <div className="dashboard-activity__table-wrap">
                <table className="dashboard-activity__table">
                  <thead>
                    <tr>
                      <th>Typ</th>
                      <th>Produkt</th>
                      <th>Mn.</th>
                      <th>Čas</th>
                    </tr>
                  </thead>
                  <tbody>
                    {batches.length === 0 ? (
                      <tr>
                        <td colSpan={4} className="dashboard-activity__empty">
                          Žiadne pohyby. Synchronizujte aplikáciu.
                        </td>
                      </tr>
                    ) : (
                      batches.slice(0, 10).map((b) => (
                        <tr key={b.id}>
                          <td><span className="dashboard-activity__type dashboard-activity__type--batch">↔</span></td>
                          <td>{b.product_type || '—'}</td>
                          <td>+{b.quantity_produced ?? 0}</td>
                          <td>{b.created_at ? formatAgo(b.created_at) : '—'}</td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
              <a href="/dashboard" className="dashboard-activity__link" onClick={(e) => { e.preventDefault(); navigate('/dashboard/production') }}>
                Zobraziť všetky pohyby →
              </a>
            </section>

            <section className="dashboard-notifications" ref={notificationsRef}>
              <h3 className="dashboard-notifications__title">Upozornenia a notifikácie</h3>
              <div className="dashboard-notifications__tabs">
                {NOTIF_TABS.map((tab) => (
                  <button
                    key={tab.id}
                    type="button"
                    className={`dashboard-notifications__tab ${notifTab === tab.id ? 'dashboard-notifications__tab--active' : ''}`}
                    onClick={() => setNotifTab(tab.id)}
                  >
                    {tab.label}
                  </button>
                ))}
              </div>
              <div className="dashboard-notifications__list">
                {displayNotifs.length === 0 ? (
                  <p className="dashboard-notifications__empty">Žiadne notifikácie</p>
                ) : (
                  displayNotifs.map((n) => (
                    <div
                      key={n.id}
                      className={`dashboard-notifications__item ${n.read ? '' : 'dashboard-notifications__item--unread'}`}
                      onClick={() => { markAsRead(n.id); if (n.link) navigate(n.link) }}
                      onKeyDown={(e) => { if (e.key === 'Enter') { markAsRead(n.id); if (n.link) navigate(n.link) } }}
                      role="button"
                      tabIndex={0}
                    >
                      <span className="dashboard-notifications__item-icon">
                        {n.type === 'critical' ? '🔴' : n.type === 'warning' ? '🟡' : n.type === 'success' ? '🟢' : '🔵'}
                      </span>
                      <div className="dashboard-notifications__item-body">
                        <strong>{n.title}</strong>
                        {n.body && <div className="dashboard-notifications__item-detail">{n.body}</div>}
                      </div>
                      <span className="dashboard-notifications__item-meta">{formatAgo(n.createdAt)}</span>
                      <span className="dashboard-notifications__item-arrow">→</span>
                    </div>
                  ))
                )}
              </div>
            </section>
          </div>

          <section className="dashboard-quick-actions">
            <button
              type="button"
              className="dashboard-quick-action"
              onClick={() => navigate('/dashboard/scan')}
            >
              <span className="dashboard-quick-action__icon">📷</span>
              <span className="dashboard-quick-action__label">Skenovať tovar</span>
            </button>
            <button
              type="button"
              className="dashboard-quick-action"
              onClick={() => navigate('/dashboard/production/new')}
            >
              <span className="dashboard-quick-action__icon">📦</span>
              <span className="dashboard-quick-action__label">Nová príjemka</span>
            </button>
            <button
              type="button"
              className="dashboard-quick-action"
              onClick={() => navigate('/dashboard/customers')}
            >
              <span className="dashboard-quick-action__icon">👥</span>
              <span className="dashboard-quick-action__label">Nový zákazník</span>
            </button>
            <button
              type="button"
              className="dashboard-quick-action"
              onClick={handleSync}
              disabled={syncing}
            >
              <span className="dashboard-quick-action__icon">
                {syncing ? <span className="dashboard-quick-action__spinner" /> : '🔄'}
              </span>
              <span className="dashboard-quick-action__label">{syncing ? 'Synchronizujem...' : 'Synchronizovať'}</span>
            </button>
          </section>
        </>
      )}
    </div>
  )
}
