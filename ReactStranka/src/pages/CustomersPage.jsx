import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import './CustomersPage.css'

const API_BASE = import.meta.env.VITE_API_URL || 'https://backend.stockpilot.sk'

export default function CustomersPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [customers, setCustomers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

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
    async function fetchCustomers() {
      try {
        const res = await fetch(`${API_BASE}/api/customers`, {
          headers: auth?.token ? { Authorization: auth.token } : {},
        })
        if (!res.ok) throw new Error('Načítanie zlyhalo')
        const data = await res.json()
        if (!cancelled) setCustomers(Array.isArray(data) ? data : [])
      } catch (e) {
        if (!cancelled) setError(e.message || 'Chyba')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    fetchCustomers()
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
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')} title="Späť na prehľad">
            ←
          </button>
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

      <main className="dashboard-main customers-main">
        <h2 className="dashboard-overview-title">Zákazníci</h2>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam zákazníkov...</span>
          </div>
        ) : error ? (
          <p className="customers-error">{error}</p>
        ) : customers.length === 0 ? (
          <p className="customers-empty">Zatiaľ nemáte žiadnych zákazníkov. Synchronizujte z aplikácie.</p>
        ) : (
          <ul className="customers-list">
            {customers.map((c) => (
              <li key={c.id}>
                <button
                  type="button"
                  className="customers-list-item"
                  onClick={() => navigate(`/dashboard/customers/${c.id}`)}
                >
                  <span className="customers-list-name">{c.name}</span>
                  <span className="customers-list-ico">IČO: {c.ico}</span>
                  {c.city && <span className="customers-list-city">{c.city}</span>}
                  {c.is_active === 0 && <span className="customers-list-inactive">Neaktívny</span>}
                </button>
              </li>
            ))}
          </ul>
        )}
      </main>

      <footer className="dashboard-footer">
        Stock Pilot &copy; {new Date().getFullYear()}
      </footer>
    </div>
  )
}
