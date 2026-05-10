import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import './CustomersPage.css'
import './ProductionPage.css'
import { getAuth, getAuthHeaders } from '../utils/auth'
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

function fmtNum(v, dec = 0) {
  return new Intl.NumberFormat('sk-SK', { minimumFractionDigits: 0, maximumFractionDigits: dec }).format(Number(v) || 0)
}

export default function ProductionPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [rangeMode, setRangeMode] = useState('month')
  const [selectedDate, setSelectedDate] = useState(todayStr())
  const [batches, setBatches] = useState([])
  const [loading, setLoading] = useState(true)
  const [apiError, setApiError] = useState(null)
  const [search, setSearch] = useState('')

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) {
      navigate('/', { replace: true })
      return
    }
    setAuth(a)
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
    fetch(url, { headers: getAuthHeaders(auth) })
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

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return batches
    return batches.filter((b) => `${b.product_type} ${b.notes || ''}`.toLowerCase().includes(q))
  }, [batches, search])

  const totals = useMemo(() => {
    return filtered.reduce(
      (acc, b) => {
        acc.pieces += Number(b.quantity_produced) || 0
        acc.m2 += Number(b.actual_stored_m2 ?? b.requested_m2 ?? 0) || 0
        acc.cost += Number(b.cost_total) || 0
        acc.revenue += Number(b.revenue_total) || 0
        return acc
      },
      { pieces: 0, m2: 0, cost: 0, revenue: 0 }
    )
  }, [filtered])

  if (!auth) return null

  return (
    <div className="dashboard-page-content production-page-wrap">
      <main className="dashboard-main customers-main">
        <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')} style={{ marginBottom: '0.5rem' }}>← Späť na prehľad</button>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '1rem' }}>
          <h2 className="dashboard-overview-title" style={{ margin: 0 }}>Výroba – šarže</h2>
          <div style={{ display: 'flex', gap: '0.5rem' }}>
            <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard/production/report')}>
              📊 Súhrn
            </button>
            <button type="button" className="dashboard-scan-card" style={{ padding: '0.5rem 1rem' }} onClick={() => navigate('/dashboard/production/new')}>
              + Nová šarža
            </button>
          </div>
        </div>

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
          <input
            type="search"
            className="production-date-input"
            placeholder="Hľadať podľa typu / poznámky…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{ flex: 1, minWidth: 180 }}
          />
        </div>

        {batches.length > 0 && (
          <div className="prod-summary-grid">
            <div className="prod-summary-card">
              <h4>Šarží v období</h4>
              <div className="num">{filtered.length}</div>
            </div>
            <div className="prod-summary-card">
              <h4>Vyrobené</h4>
              <div className="num">{fmtNum(totals.pieces)} ks</div>
              {totals.m2 > 0 && <span className="sub">{fmtNum(totals.m2, 2)} m²</span>}
            </div>
            <div className="prod-summary-card">
              <h4>Náklady / Výnos</h4>
              <div className="num">{fmtNum(totals.cost, 2)} €</div>
              <span className="sub">výnos {fmtNum(totals.revenue, 2)} €</span>
            </div>
          </div>
        )}

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
        ) : filtered.length === 0 ? (
          <div className="production-empty">
            <p>
              {batches.length === 0
                ? (rangeMode === 'day' ? 'V tento deň nie sú žiadne šarže.' : 'V zvolenom období nie sú žiadne šarže.')
                : 'Žiadne výsledky pre zadaný filter.'}
            </p>
            {batches.length === 0 && (
              <button
                type="button"
                className="dashboard-scan-card production-add-btn"
                onClick={() => navigate('/dashboard/production/new')}
              >
                Pridať šaržu
              </button>
            )}
          </div>
        ) : (
          <ul className="production-list">
            {filtered.map((b) => (
              <li key={b.id} className="production-list-item">
                <button
                  type="button"
                  className="production-list-card"
                  onClick={() => navigate(`/dashboard/production/${b.id}`)}
                >
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div className="production-list-type">{b.product_type}</div>
                    <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '0.15rem' }}>
                      {formatDate(b.production_date)}
                    </div>
                  </div>
                  <span className="production-list-qty">
                    {fmtNum(b.quantity_produced)} ks
                    {b.actual_stored_m2 != null ? ` · ${Number(b.actual_stored_m2).toFixed(1)} m²` : (b.requested_m2 != null ? ` · ${Number(b.requested_m2).toFixed(1)} m²` : '')}
                  </span>
                  <span className="production-list-arrow">→</span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </main>
    </div>
  )
}
