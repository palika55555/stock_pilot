import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'

const API_BASE = import.meta.env.VITE_API_URL || 'https://backend.stockpilot.sk'

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

export default function DashboardPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [stats, setStats] = useState({
    products: 0,
    orders: 0,
    customers: 0,
    revenue: 0,
    inboundCount: 0,
    outboundCount: 0,
    quotesCount: 0,
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const raw = localStorage.getItem('stockpilot_auth')
    if (!raw) {
      navigate('/', { replace: true })
      return
    }
    try {
      setAuth(JSON.parse(raw))
    } catch {
      navigate('/', { replace: true })
    }
  }, [navigate])

  useEffect(() => {
    if (!auth) return
    let cancelled = false
    async function fetchStats() {
      try {
        const res = await fetch(`${API_BASE}/api/dashboard/stats`, {
          headers: auth?.token ? { Authorization: `Bearer ${auth.token}` } : {},
        })
        if (!res.ok) throw new Error('Stats failed')
        const data = await res.json()
        if (!cancelled) setStats(data)
      } catch {
        if (!cancelled) setStats((s) => ({ ...s }))
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    fetchStats()
    return () => { cancelled = true }
  }, [auth])

  const handleLogout = () => {
    localStorage.removeItem('stockpilot_auth')
    navigate('/', { replace: true })
  }

  if (!auth) return null

  return (
    <div className="dashboard-page">
      <header className="dashboard-header">
        <div className="dashboard-brand">
          <span className="dashboard-logo-label">STOCK</span>
          <h1 className="dashboard-logo-title">PILOT</h1>
        </div>
        <div className="dashboard-user">
          <span className="dashboard-user-name">{auth.user?.fullName || auth.user?.username || 'Používateľ'}</span>
          <span className="dashboard-user-role">{auth.user?.role || 'user'}</span>
          <button type="button" className="btn-logout" onClick={handleLogout}>
            Odhlásiť sa
          </button>
        </div>
      </header>

      <main className="dashboard-main">
        <h2 className="dashboard-overview-title">Prehľad</h2>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam...</span>
          </div>
        ) : (
          <>
            <div className="dashboard-kpi-grid">
              <div className="dashboard-kpi-card">
                <span className="dashboard-kpi-title">Produkty</span>
                <span className="dashboard-kpi-value">{stats.products}</span>
              </div>
              <div className="dashboard-kpi-card">
                <span className="dashboard-kpi-title">Objednávky</span>
                <span className="dashboard-kpi-value">{stats.orders}</span>
              </div>
              <div
                className="dashboard-kpi-card dashboard-kpi-card--clickable"
                role="button"
                tabIndex={0}
                onClick={() => navigate('/dashboard/customers')}
                onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); navigate('/dashboard/customers') } }}
              >
                <span className="dashboard-kpi-title">Zákazníci</span>
                <span className="dashboard-kpi-value">{stats.customers}</span>
              </div>
              <div className="dashboard-kpi-card">
                <span className="dashboard-kpi-title">Tržby</span>
                <span className="dashboard-kpi-value">{formatCurrency(stats.revenue)}</span>
              </div>
            </div>

            <section className="dashboard-section">
              <h3 className="dashboard-section-title">Poznámky</h3>
              <div className="dashboard-notes-placeholder">
                Rovnaké informácie ako v aplikácii – poznámky a úlohy môžete pridať neskôr.
              </div>
            </section>

            <section className="dashboard-section">
              <h3 className="dashboard-section-title">Nedávne pohyby</h3>
              <div className="dashboard-movements-placeholder">
                Príjemky a výdajky sa zobrazia po synchronizácii s backendom.
              </div>
            </section>
          </>
        )}
      </main>

      <footer className="dashboard-footer">
        Stock Pilot &copy; {new Date().getFullYear()}
      </footer>
    </div>
  )
}
