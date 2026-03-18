import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'
import './sync-pages.css'

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('sk-SK')
}

const STATUS_MAP = {
  schvaleny:    { label: 'Schválený',          cls: 'sync-badge--green' },
  approved:     { label: 'Schválený',          cls: 'sync-badge--green' },
  pending:      { label: 'Čaká na schválenie', cls: 'sync-badge--amber' },
  submitted:    { label: 'Odoslaný',           cls: 'sync-badge--blue' },
  rozpracovany: { label: 'Rozpracovaný',       cls: 'sync-badge--gray' },
  draft:        { label: 'Koncept',            cls: 'sync-badge--gray' },
  rejected:     { label: 'Zamietnutý',         cls: 'sync-badge--red' },
  storno:       { label: 'Storno',             cls: 'sync-badge--red' },
}

const ISSUE_TYPE_LABELS = {
  sale:        'Predaj',
  production:  'Výroba',
  write_off:   'Odpis',
  transfer:    'Presun',
  return:      'Vrátenie',
  other:       'Iné',
}

function statusBadge(status) {
  const s = STATUS_MAP[status] ?? { label: status ?? '—', cls: 'sync-badge--gray' }
  return <span className={`sync-badge ${s.cls}`}>{s.label}</span>
}

export default function VydajkyPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [stockOuts, setStockOuts] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [typeFilter, setTypeFilter] = useState('')

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  useEffect(() => {
    if (!auth) return
    let cancelled = false
    setLoading(true)
    fetch(`${API_BASE_FOR_CALLS}/stock-outs/all`, { headers: getAuthHeaders(auth) })
      .then((r) => r.ok ? r.json() : Promise.reject(r.status))
      .then((d) => { if (!cancelled) setStockOuts(Array.isArray(d?.stock_outs) ? d.stock_outs : []) })
      .catch((e) => { if (!cancelled) setError(`Načítanie zlyhalo (${e})`) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [auth])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return stockOuts.filter((s) => {
      if (statusFilter && s.status !== statusFilter) return false
      if (typeFilter && s.issue_type !== typeFilter) return false
      if (q) {
        const hay = `${s.document_number} ${s.recipient_name ?? ''}`.toLowerCase()
        if (!hay.includes(q)) return false
      }
      return true
    })
  }, [stockOuts, search, statusFilter, typeFilter])

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main sync-page">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <h2 className="dashboard-overview-title">Výdajky</h2>
        </div>

        <div className="sync-readonly-banner">
          ℹ️ Dáta sú synchronizované z Flutter aplikácie. Editácia prebieha v aplikácii.
        </div>

        <div className="sync-filters">
          <input
            type="search"
            className="sync-search"
            placeholder="Hľadať podľa čísla alebo príjemcu…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <select className="sync-select" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
            <option value="">Všetky stavy</option>
            <option value="schvaleny">Schválený</option>
            <option value="pending">Čaká na schválenie</option>
            <option value="rozpracovany">Rozpracovaný</option>
            <option value="rejected">Zamietnutý</option>
            <option value="storno">Storno</option>
          </select>
          <select className="sync-select" value={typeFilter} onChange={(e) => setTypeFilter(e.target.value)}>
            <option value="">Všetky typy</option>
            {Object.entries(ISSUE_TYPE_LABELS).map(([v, l]) => (
              <option key={v} value={v}>{l}</option>
            ))}
          </select>
        </div>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam výdajky...</span>
          </div>
        ) : error ? (
          <p className="customers-error">{error}</p>
        ) : filtered.length === 0 ? (
          <div className="sync-empty">
            {stockOuts.length === 0
              ? 'Žiadne výdajky. Vytvorte ich v mobilnej aplikácii.'
              : 'Žiadne výsledky pre zadaný filter.'}
          </div>
        ) : (
          <ul className="sync-list">
            {filtered.map((s) => (
              <li key={s.id} className="sync-list-item">
                <div className="sync-list-item__body">
                  <div className="sync-list-item__top">
                    <span className="sync-list-item__number">{s.document_number}</span>
                    {statusBadge(s.status)}
                    {s.issue_type && (
                      <span className="sync-badge sync-badge--blue">
                        {ISSUE_TYPE_LABELS[s.issue_type] ?? s.issue_type}
                      </span>
                    )}
                  </div>
                  <span className="sync-list-item__sub">{s.recipient_name || '—'}</span>
                  <div className="sync-list-item__meta">
                    <span>Dátum: {fmtDate(s.created_at)}</span>
                    {s.notes && <span style={{ maxWidth: 260, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.notes}</span>}
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
