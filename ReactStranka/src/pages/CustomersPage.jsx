import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import './CustomersPage.css'
import { API_BASE_FOR_CALLS } from '../config'

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
        const res = await fetch(`${API_BASE_FOR_CALLS}/customers`, {
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

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main customers-main">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')} title="Späť na prehľad">← Späť</button>
          <h2 className="dashboard-overview-title">Zákazníci</h2>
        </div>

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
    </div>
  )
}
