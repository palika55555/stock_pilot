import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { getAuth, getAuthHeaders } from '../utils/auth'
import { apiFetch } from '../utils/apiFetch'
import { API_BASE_FOR_CALLS } from '../config'
import './sync-pages.css'

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('sk-SK')
}

function fmtNum(v, dec = 2) {
  return new Intl.NumberFormat('sk-SK', { minimumFractionDigits: 0, maximumFractionDigits: dec }).format(Number(v) || 0)
}

function fmtEur(v) {
  return new Intl.NumberFormat('sk-SK', { style: 'currency', currency: 'EUR' }).format(Number(v) || 0)
}

const STATUS_MAP = {
  draft:       { label: 'Koncept',          cls: 'sync-badge--gray' },
  pending:     { label: 'Čaká na schválenie', cls: 'sync-badge--amber' },
  approved:    { label: 'Schválený',         cls: 'sync-badge--green' },
  rejected:    { label: 'Zamietnutý',        cls: 'sync-badge--red' },
  in_progress: { label: 'Prebieha výroba',   cls: 'sync-badge--inprogress' },
  completed:   { label: 'Dokončený',         cls: 'sync-badge--completed' },
  cancelled:   { label: 'Zrušený',           cls: 'sync-badge--red' },
}

function statusBadge(status) {
  const s = STATUS_MAP[status] ?? { label: status ?? '—', cls: 'sync-badge--gray' }
  return <span className={`sync-badge ${s.cls}`}>{s.label}</span>
}

export default function VyrobneProkazaPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [orders, setOrders] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('')

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  useEffect(() => {
    if (!auth) return
    let cancelled = false
    setLoading(true)
    fetch(`${API_BASE_FOR_CALLS}/production-orders/all`, { headers: getAuthHeaders(auth) })
      .then((r) => r.ok ? r.json() : Promise.reject(r.status))
      .then((d) => { if (!cancelled) setOrders(Array.isArray(d?.production_orders) ? d.production_orders : []) })
      .catch((e) => { if (!cancelled) setError(`Načítanie zlyhalo (${e})`) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [auth])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return orders.filter((o) => {
      if (statusFilter && o.status !== statusFilter) return false
      if (q) {
        const hay = `${o.order_number} ${o.recipe_name ?? ''}`.toLowerCase()
        if (!hay.includes(q)) return false
      }
      return true
    })
  }, [orders, search, statusFilter])

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main sync-page">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <h2 className="dashboard-overview-title">Výrobné príkazy</h2>
        </div>

        <div className="sync-readonly-banner">
          ℹ️ Dáta sú synchronizované z Flutter aplikácie. Editácia prebieha v aplikácii.
        </div>

        <div className="sync-filters">
          <input
            type="search"
            className="sync-search"
            placeholder="Hľadať podľa čísla alebo receptúry…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <select className="sync-select" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
            <option value="">Všetky stavy</option>
            {Object.entries(STATUS_MAP).map(([v, { label }]) => (
              <option key={v} value={v}>{label}</option>
            ))}
          </select>
        </div>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam výrobné príkazy...</span>
          </div>
        ) : error ? (
          <p className="customers-error">{error}</p>
        ) : filtered.length === 0 ? (
          <div className="sync-empty">
            {orders.length === 0
              ? 'Žiadne výrobné príkazy. Vytvorte ich v mobilnej aplikácii.'
              : 'Žiadne výsledky pre zadaný filter.'}
          </div>
        ) : (
          <ul className="sync-list">
            {filtered.map((o) => (
              <li key={o.id} className="sync-list-item">
                <div className="sync-list-item__body">
                  <div className="sync-list-item__top">
                    <span className="sync-list-item__number">{o.order_number}</span>
                    {statusBadge(o.status)}
                  </div>
                  <span className="sync-list-item__sub">{o.recipe_name || '—'}</span>
                  <div className="sync-list-item__meta">
                    <span>Plánované: <span className="sync-list-item__accent">{fmtNum(o.planned_quantity, 0)}</span></span>
                    {o.actual_quantity != null && (
                      <span>Skutočné: <span className="sync-list-item__accent">{fmtNum(o.actual_quantity, 0)}</span></span>
                    )}
                    <span>Dátum výroby: {fmtDate(o.production_date)}</span>
                    {o.completed_at && <span>Dokončené: {fmtDate(o.completed_at)}</span>}
                    {o.total_cost != null && Number(o.total_cost) > 0 && (
                      <span>Náklady: <span className="sync-list-item__accent">{fmtEur(o.total_cost)}</span></span>
                    )}
                    {o.created_by_username && <span>Vytvoril: {o.created_by_username}</span>}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </main>
    </div>
  )
}
