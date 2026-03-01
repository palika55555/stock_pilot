import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import './CustomersPage.css'
import './ProductionPage.css'
import { API_BASE_FOR_CALLS } from '../config'

function formatDate(d) {
  if (!d) return ''
  const x = typeof d === 'string' ? d.slice(0, 10) : d
  const [y, m, day] = x.split('-')
  return `${parseInt(day, 10)}. ${parseInt(m, 10)}. ${y}`
}

function todayStr() {
  const d = new Date()
  return d.toISOString().slice(0, 10)
}

export default function ProductionPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [selectedDate, setSelectedDate] = useState(todayStr())
  const [batches, setBatches] = useState([])
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
    if (!auth?.token) return
    let cancelled = false
    setLoading(true)
    fetch(`${API_BASE_FOR_CALLS}/batches?date=${selectedDate}`, {
      headers: { Authorization: auth.token },
    })
      .then((res) => (res.ok ? res.json() : []))
      .then((data) => { if (!cancelled) setBatches(Array.isArray(data) ? data : []) })
      .catch(() => { if (!cancelled) setBatches([]) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [auth?.token, selectedDate])

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
          <button type="button" className="btn-logout" onClick={() => { localStorage.removeItem('stockpilot_auth'); navigate('/', { replace: true }) }}>
            Odhlásiť sa
          </button>
        </div>
      </header>

      <main className="dashboard-main customers-main">
        <h2 className="dashboard-overview-title">Výroba – šarže</h2>

        <div className="production-date-row">
          <label className="production-date-label">Dátum výroby:</label>
          <input
            type="date"
            className="production-date-input"
            value={selectedDate}
            onChange={(e) => setSelectedDate(e.target.value.slice(0, 10))}
          />
        </div>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam šarže...</span>
          </div>
        ) : batches.length === 0 ? (
          <div className="production-empty">
            <p>V tento deň nie sú žiadne šarže.</p>
            <button
              type="button"
              className="dashboard-scan-card production-add-btn"
              onClick={() => navigate('/dashboard/production/new')}
            >
              Pridať šaržu
            </button>
          </div>
        ) : (
          <>
            <ul className="production-list">
              {batches.map((b) => (
                <li key={b.id} className="production-list-item">
                  <button
                    type="button"
                    className="production-list-card"
                    onClick={() => navigate(`/dashboard/production/${b.id}`)}
                  >
                    <span className="production-list-type">{b.product_type}</span>
                    <span className="production-list-qty">{b.quantity_produced} ks</span>
                    <span className="production-list-arrow">→</span>
                  </button>
                </li>
              ))}
            </ul>
            <button
              type="button"
              className="dashboard-scan-card production-add-btn"
              onClick={() => navigate('/dashboard/production/new')}
            >
              + Pridať šaržu
            </button>
          </>
        )}
      </main>
    </div>
  )
}
