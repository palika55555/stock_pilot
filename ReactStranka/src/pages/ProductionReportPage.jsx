import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import './CustomersPage.css'
import './ProductionPage.css'
import { getAuth, getAuthHeaders } from '../utils/auth'
import { API_BASE_FOR_CALLS } from '../config'

function todayStr() {
  return new Date().toISOString().slice(0, 10)
}

function daysAgoStr(days) {
  const d = new Date()
  d.setDate(d.getDate() - days)
  return d.toISOString().slice(0, 10)
}

function fmtNum(v, dec = 0) {
  return new Intl.NumberFormat('sk-SK', { minimumFractionDigits: 0, maximumFractionDigits: dec }).format(Number(v) || 0)
}

function fmtEur(v) {
  return new Intl.NumberFormat('sk-SK', { style: 'currency', currency: 'EUR' }).format(Number(v) || 0)
}

const STATUS_LABELS = {
  'Na sklade': { label: 'Na sklade', cls: 'is-stock' },
  'U zákazníka': { label: 'U zákazníka', cls: 'is-cust' },
  Predané: { label: 'Predané', cls: 'is-sold' },
  Expedované: { label: 'Expedované', cls: 'is-sold' },
  Rezervované: { label: 'Rezervované', cls: 'is-other' },
}

function statusInfo(s) {
  return STATUS_LABELS[s] || { label: s || '—', cls: 'is-other' }
}

export default function ProductionReportPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [from, setFrom] = useState(daysAgoStr(31))
  const [to, setTo] = useState(todayStr())
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  useEffect(() => {
    if (!auth?.token) return
    let cancelled = false
    setLoading(true)
    setError('')
    fetch(`${API_BASE_FOR_CALLS}/production/summary?from=${from}&to=${to}`, { headers: getAuthHeaders(auth) })
      .then((r) => (r.ok ? r.json() : r.json().then((d) => Promise.reject(new Error(d.error || 'Načítanie')))))
      .then((d) => { if (!cancelled) setData(d) })
      .catch((err) => { if (!cancelled) setError(err.message || 'Chyba pri načítaní') })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [auth?.token, from, to])

  const setRange = (days) => {
    setFrom(daysAgoStr(days))
    setTo(todayStr())
  }

  const downloadCsv = () => {
    if (!auth?.token) return
    const url = `${API_BASE_FOR_CALLS}/production/export.csv?from=${from}&to=${to}`
    fetch(url, { headers: getAuthHeaders(auth) })
      .then(async (r) => {
        if (!r.ok) throw new Error('Export zlyhal')
        const blob = await r.blob()
        const a = document.createElement('a')
        a.href = URL.createObjectURL(blob)
        a.download = `vyroba-${from}-az-${to}.csv`
        a.click()
        URL.revokeObjectURL(a.href)
      })
      .catch((err) => setError(err.message || 'Export zlyhal'))
  }

  const margin = useMemo(() => {
    if (!data) return null
    const rev = Number(data.total_revenue) || 0
    const cost = Number(data.total_cost) || 0
    if (rev <= 0) return null
    return ((rev - cost) / rev) * 100
  }, [data])

  if (!auth) return null

  return (
    <div className="dashboard-page-content production-page-wrap">
      <main className="dashboard-main customers-main">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <h2 className="dashboard-overview-title">Súhrn výroby</h2>
        </div>

        <div className="production-date-row">
          <span className="production-date-label">Obdobie:</span>
          <input type="date" className="production-date-input" value={from} onChange={(e) => setFrom(e.target.value.slice(0, 10))} />
          <span style={{ color: 'var(--text-muted)' }}>—</span>
          <input type="date" className="production-date-input" value={to} onChange={(e) => setTo(e.target.value.slice(0, 10))} />
          <button type="button" className="production-date-input" onClick={() => setRange(7)}>7 dní</button>
          <button type="button" className="production-date-input" onClick={() => setRange(31)}>31 dní</button>
          <button type="button" className="production-date-input" onClick={() => setRange(365)}>Rok</button>
          <button type="button" className="production-date-input" onClick={downloadCsv}>⬇ Export CSV</button>
        </div>

        {error ? <div className="production-error-box">{error}</div> : null}

        {loading || !data ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam súhrn…</span>
          </div>
        ) : (
          <>
            <div className="prod-summary-grid">
              <div className="prod-summary-card">
                <h4>Vyrobené ks</h4>
                <div className="num">{fmtNum(data.total_produced_pieces)}</div>
                <span className="sub">{data.total_batches} šarží</span>
              </div>
              <div className="prod-summary-card">
                <h4>Vyrobené m²</h4>
                <div className="num">{fmtNum(data.total_produced_m2, 2)}</div>
                <span className="sub">len dlažba (uložené m²)</span>
              </div>
              <div className="prod-summary-card">
                <h4>Predané ks</h4>
                <div className="num">{fmtNum(data.sold_pieces)}</div>
                <span className="sub">{data.sold_pallets} paliet</span>
              </div>
              <div className="prod-summary-card">
                <h4>Náklady</h4>
                <div className="num">{fmtEur(data.total_cost)}</div>
                <span className="sub">súčet šarží</span>
              </div>
              <div className="prod-summary-card">
                <h4>Výnos</h4>
                <div className="num">{fmtEur(data.total_revenue)}</div>
                <span className="sub">{margin != null ? `marža ${margin.toFixed(1)} %` : 'marža —'}</span>
              </div>
            </div>

            <h3 className="dashboard-section-title">Stav paliet podľa statusu</h3>
            <table className="prod-table">
              <thead>
                <tr>
                  <th>Status</th>
                  <th className="num">Palety</th>
                  <th className="num">Kusy</th>
                </tr>
              </thead>
              <tbody>
                {(data.pallets_by_status || []).length === 0 && (
                  <tr><td colSpan={3} style={{ color: 'var(--text-muted)' }}>Zatiaľ žiadne palety</td></tr>
                )}
                {(data.pallets_by_status || []).map((r) => {
                  const info = statusInfo(r.status)
                  return (
                    <tr key={r.status}>
                      <td><span className={`prod-pallet-status ${info.cls}`}>{info.label}</span></td>
                      <td className="num">{fmtNum(r.pallets)}</td>
                      <td className="num">{fmtNum(r.pieces)}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>

            <h3 className="dashboard-section-title">Podľa typu výrobku</h3>
            <table className="prod-table">
              <thead>
                <tr>
                  <th>Typ</th>
                  <th className="num">Vyrobené ks</th>
                  <th className="num">Vyrobené m²</th>
                  <th className="num">Na sklade</th>
                  <th className="num">U zákazníka</th>
                  <th className="num">Predané</th>
                </tr>
              </thead>
              <tbody>
                {(data.by_product_type || []).length === 0 && (
                  <tr><td colSpan={6} style={{ color: 'var(--text-muted)' }}>Žiadne dáta v období</td></tr>
                )}
                {(data.by_product_type || []).map((r) => (
                  <tr key={r.product_type}>
                    <td>{r.product_type}</td>
                    <td className="num">{fmtNum(r.produced_pieces)}</td>
                    <td className="num">{r.produced_m2 > 0 ? fmtNum(r.produced_m2, 2) : '—'}</td>
                    <td className="num">{fmtNum(r.in_stock_pieces)}</td>
                    <td className="num">{fmtNum(r.at_customer_pieces)}</td>
                    <td className="num">{fmtNum(r.sold_pieces)}</td>
                  </tr>
                ))}
              </tbody>
            </table>

            {(data.top_customers || []).length > 0 && (
              <>
                <h3 className="dashboard-section-title">Top zákazníci (v období)</h3>
                <table className="prod-table">
                  <thead>
                    <tr>
                      <th>Zákazník</th>
                      <th className="num">Palety</th>
                      <th className="num">Kusy</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.top_customers.map((c) => (
                      <tr key={c.id}>
                        <td>
                          <button
                            type="button"
                            className="dashboard-back"
                            style={{ padding: 0, color: 'var(--accent)' }}
                            onClick={() => navigate(`/dashboard/customers/${c.id}`)}
                          >
                            {c.name}
                          </button>
                        </td>
                        <td className="num">{fmtNum(c.pallets)}</td>
                        <td className="num">{fmtNum(c.pieces)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </>
            )}

            {(data.daily || []).length > 0 && (
              <>
                <h3 className="dashboard-section-title">Denná výroba</h3>
                <table className="prod-table">
                  <thead>
                    <tr>
                      <th>Deň</th>
                      <th className="num">Kusy</th>
                      <th className="num">m²</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.daily.map((d) => (
                      <tr key={d.day}>
                        <td>{new Date(d.day).toLocaleDateString('sk-SK')}</td>
                        <td className="num">{fmtNum(d.pieces)}</td>
                        <td className="num">{d.m2 > 0 ? fmtNum(d.m2, 2) : '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </>
            )}
          </>
        )}
      </main>
    </div>
  )
}
