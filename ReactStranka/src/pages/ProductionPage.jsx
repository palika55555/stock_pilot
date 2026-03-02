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

function dateRange(daysBack) {
  const end = new Date()
  const start = new Date()
  start.setDate(start.getDate() - daysBack)
  return {
    from: start.toISOString().slice(0, 10),
    to: end.toISOString().slice(0, 10),
  }
}

export default function ProductionPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [rangeMode, setRangeMode] = useState('month') // 'day' | 'month' | 'all'
  const [selectedDate, setSelectedDate] = useState(todayStr())
  const [batches, setBatches] = useState([])
  const [loading, setLoading] = useState(true)
  const [apiError, setApiError] = useState(null)

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
    setApiError(null)
    let url = `${API_BASE_FOR_CALLS}/batches`
    if (rangeMode === 'day') {
      url += `?date=${selectedDate}`
    } else {
      const r = rangeMode === 'month' ? dateRange(31) : dateRange(365)
      url += `?from=${r.from}&to=${r.to}`
    }
    fetch(url, { headers: { Authorization: auth.token } })
      .then((res) => {
        if (!res.ok) {
          if (!cancelled) setApiError(res.status === 503 ? 'Backend alebo databáza nie sú dostupné.' : `Chyba ${res.status}. Skúste obnoviť alebo synchronizovať z aplikácie.`)
          return []
        }
        return res.json()
      })
      .then((data) => { if (!cancelled) setBatches(Array.isArray(data) ? data : []) })
      .catch(() => {
        if (!cancelled) {
          setApiError('Nepodarilo sa načítať šarže. Skontrolujte sieť a prihlásenie.')
          setBatches([])
        }
      })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [auth?.token, selectedDate, rangeMode])

  if (!auth) return null

  return (
    <div className="dashboard-page-content production-page-wrap">
      <main className="dashboard-main customers-main">
        <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')} style={{ marginBottom: '0.5rem' }}>← Späť na prehľad</button>
        <h2 className="dashboard-overview-title">Výroba – šarže</h2>

        <div className="production-date-row" style={{ flexWrap: 'wrap', gap: '0.75rem', alignItems: 'center' }}>
          <span className="production-date-label">Obdobie:</span>
          <select
            value={rangeMode}
            onChange={(e) => setRangeMode(e.target.value)}
            className="production-date-input"
            style={{ width: 'auto', minWidth: '140px' }}
          >
            <option value="day">Jeden deň</option>
            <option value="month">Posledných 31 dní</option>
            <option value="all">Posledný rok</option>
          </select>
          {rangeMode === 'day' && (
            <input
              type="date"
              className="production-date-input"
              value={selectedDate}
              onChange={(e) => setSelectedDate(e.target.value.slice(0, 10))}
            />
          )}
        </div>

        {apiError && (
          <div className="production-error-box">
            {apiError}
          </div>
        )}

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam šarže...</span>
          </div>
        ) : batches.length === 0 ? (
          <div className="production-empty">
            <p>
              {rangeMode === 'day' ? 'V tento deň nie sú žiadne šarže.' : 'V zvolenom období nie sú žiadne šarže.'}
              {' '}Vytvorte šaržu v aplikácii a prihláste sa (sync na backend), alebo pridajte šaržu tu.
            </p>
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
