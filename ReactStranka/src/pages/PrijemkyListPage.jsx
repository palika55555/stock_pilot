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
  schvalena:     { label: 'Schválená',           cls: 'sync-badge--green' },
  approved:      { label: 'Schválená',           cls: 'sync-badge--green' },
  vysporiadana:  { label: 'Vysporiadaná',        cls: 'sync-badge--green' },
  pending:       { label: 'Čaká na schválenie',  cls: 'sync-badge--amber' },
  submitted:     { label: 'Odoslaná',            cls: 'sync-badge--blue' },
  rozpracovany:  { label: 'Rozpracovaná',        cls: 'sync-badge--gray' },
  draft:         { label: 'Koncept',             cls: 'sync-badge--gray' },
  rejected:      { label: 'Zamietnutá',          cls: 'sync-badge--red' },
  storno:        { label: 'Storno',              cls: 'sync-badge--red' },
  reversed:      { label: 'Storno',              cls: 'sync-badge--red' },
}

function statusBadge(status) {
  const s = STATUS_MAP[status] ?? { label: status ?? '—', cls: 'sync-badge--gray' }
  return <span className={`sync-badge ${s.cls}`}>{s.label}</span>
}

export default function PrijemkyListPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [receipts, setReceipts] = useState([])
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
    fetch(`${API_BASE_FOR_CALLS}/receipts/all`, { headers: getAuthHeaders(auth) })
      .then((r) => r.ok ? r.json() : Promise.reject(r.status))
      .then((d) => { if (!cancelled) setReceipts(Array.isArray(d?.receipts) ? d.receipts : []) })
      .catch((e) => { if (!cancelled) setError(`Načítanie zlyhalo (${e})`) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [auth])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return receipts.filter((r) => {
      if (statusFilter && r.status !== statusFilter) return false
      if (q) {
        const hay = `${r.receipt_number} ${r.supplier_name ?? ''}`.toLowerCase()
        if (!hay.includes(q)) return false
      }
      return true
    })
  }, [receipts, search, statusFilter])

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main sync-page">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <h2 className="dashboard-overview-title">Príjemky</h2>
        </div>

        <div className="sync-readonly-banner">
          ℹ️ Dáta sú synchronizované z Flutter aplikácie. Editácia prebieha v aplikácii.
        </div>

        <div className="sync-filters">
          <input
            type="search"
            className="sync-search"
            placeholder="Hľadať podľa čísla alebo dodávateľa…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <select className="sync-select" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
            <option value="">Všetky stavy</option>
            <option value="schvalena">Schválená</option>
            <option value="pending">Čaká na schválenie</option>
            <option value="rozpracovany">Rozpracovaná</option>
            <option value="rejected">Zamietnutá</option>
            <option value="storno">Storno</option>
          </select>
        </div>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam príjemky...</span>
          </div>
        ) : error ? (
          <p className="customers-error">{error}</p>
        ) : filtered.length === 0 ? (
          <div className="sync-empty">
            {receipts.length === 0
              ? 'Žiadne príjemky. Vytvorte ich v mobilnej aplikácii.'
              : 'Žiadne výsledky pre zadaný filter.'}
          </div>
        ) : (
          <ul className="sync-list">
            {filtered.map((r) => (
              <li key={r.id} className="sync-list-item">
                <div className="sync-list-item__body">
                  <div className="sync-list-item__top">
                    <span className="sync-list-item__number">{r.receipt_number}</span>
                    {statusBadge(r.status)}
                  </div>
                  <span className="sync-list-item__sub">{r.supplier_name || '—'}</span>
                  <div className="sync-list-item__meta">
                    <span>Dátum: {fmtDate(r.created_at)}</span>
                    {r.invoice_number && <span>Faktúra: {r.invoice_number}</span>}
                    {r.movement_type_code && r.movement_type_code !== 'STANDARD' && (
                      <span>Typ: {r.movement_type_code}</span>
                    )}
                    {r.notes && <span style={{ maxWidth: 260, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.notes}</span>}
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
