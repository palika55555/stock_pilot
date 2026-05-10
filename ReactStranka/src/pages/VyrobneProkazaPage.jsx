import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { getAuth, getAuthHeaders } from '../utils/auth'
import { API_BASE_FOR_CALLS } from '../config'
import './sync-pages.css'

function fmtDate(iso) {
  if (!iso) return '—'
  const d = typeof iso === 'string' ? iso.slice(0, 10) : iso
  try {
    return new Date(d).toLocaleDateString('sk-SK')
  } catch {
    return '—'
  }
}

function fmtNum(v, dec = 2) {
  return new Intl.NumberFormat('sk-SK', { minimumFractionDigits: 0, maximumFractionDigits: dec }).format(Number(v) || 0)
}

function fmtEur(v) {
  return new Intl.NumberFormat('sk-SK', { style: 'currency', currency: 'EUR' }).format(Number(v) || 0)
}

const STATUS_MAP = {
  draft: { label: 'Koncept', cls: 'sync-badge--gray' },
  pending: { label: 'Čaká na schválenie', cls: 'sync-badge--amber' },
  approved: { label: 'Schválený', cls: 'sync-badge--green' },
  rejected: { label: 'Zamietnutý', cls: 'sync-badge--red' },
  in_progress: { label: 'Prebieha výroba', cls: 'sync-badge--inprogress' },
  completed: { label: 'Dokončený', cls: 'sync-badge--completed' },
  cancelled: { label: 'Zrušený', cls: 'sync-badge--red' },
}

function statusBadge(status) {
  const s = STATUS_MAP[status] ?? { label: status ?? '—', cls: 'sync-badge--gray' }
  return <span className={`sync-badge ${s.cls}`}>{s.label}</span>
}

export default function VyrobneProkazaPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [orders, setOrders] = useState([])
  const [recipes, setRecipes] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [recipeId, setRecipeId] = useState('')
  const [plannedQty, setPlannedQty] = useState('1')
  const [prodDate, setProdDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [poNotes, setPoNotes] = useState('')
  const [requiresApproval, setRequiresApproval] = useState(false)
  const [creating, setCreating] = useState(false)
  const [patching, setPatching] = useState(null)
  const [autoBatch, setAutoBatch] = useState(true)

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  const loadOrders = () => {
    if (!auth?.token) return
    setLoading(true)
    fetch(`${API_BASE_FOR_CALLS}/production-orders/all`, { headers: getAuthHeaders(auth) })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((d) => { setOrders(Array.isArray(d?.production_orders) ? d.production_orders : []) })
      .catch((e) => setError(`Načítanie zlyhalo (${e})`))
      .finally(() => setLoading(false))
  }

  const loadRecipes = () => {
    if (!auth?.token) return
    fetch(`${API_BASE_FOR_CALLS}/recipes/all`, { headers: getAuthHeaders(auth) })
      .then((r) => (r.ok ? r.json() : Promise.reject()))
      .then((d) => setRecipes(Array.isArray(d?.recipes) ? d.recipes : []))
      .catch(() => {})
  }

  useEffect(() => {
    if (!auth) return
    loadOrders()
    loadRecipes()
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

  const createOrder = (e) => {
    e.preventDefault()
    if (!auth?.token) return
    const rid = parseInt(recipeId, 10)
    const pq = parseFloat(String(plannedQty).replace(',', '.'))
    if (!rid || !(pq > 0)) {
      setError('Vyberte receptúru a zadajte plánované množstvo.')
      return
    }
    setError('')
    setCreating(true)
    fetch(`${API_BASE_FOR_CALLS}/production-orders`, {
      method: 'POST',
      headers: getAuthHeaders(auth),
      body: JSON.stringify({
        recipe_id: rid,
        planned_quantity: pq,
        production_date: prodDate,
        notes: poNotes.trim() || undefined,
        requires_approval: requiresApproval,
      }),
    })
      .then((r) => (r.ok ? r.json() : r.json().then((d) => Promise.reject(new Error(d.error)))))
      .then(() => {
        setRecipeId('')
        setPlannedQty('1')
        setPoNotes('')
        setRequiresApproval(false)
        loadOrders()
      })
      .catch((err) => setError(err.message || 'Vytvorenie zlyhalo'))
      .finally(() => setCreating(false))
  }

  const patchStatus = (orderId, status, extra = {}) => {
    if (!auth?.token) return
    setPatching(orderId)
    setError('')
    fetch(`${API_BASE_FOR_CALLS}/production-orders/${orderId}/status`, {
      method: 'PATCH',
      headers: getAuthHeaders(auth),
      body: JSON.stringify({ status, ...extra }),
    })
      .then((r) => (r.ok ? r.json() : r.json().then((d) => Promise.reject(new Error(d.error)))))
      .then((res) => {
        if (res?.created_batch?.id) {
          if (window.confirm(`Vytvorená šarža #${res.created_batch.id}. Otvoriť detail (na palety, predaj atď.)?`)) {
            navigate(`/dashboard/production/${res.created_batch.id}`)
          }
        }
        loadOrders()
      })
      .catch((err) => setError(err.message || 'Zmena stavu zlyhala'))
      .finally(() => setPatching(null))
  }

  const deleteOrder = (orderId) => {
    if (!auth?.token || !window.confirm('Trvalo zmazať tento príkaz?')) return
    fetch(`${API_BASE_FOR_CALLS}/production-orders/${orderId}`, { method: 'DELETE', headers: getAuthHeaders(auth) })
      .then((r) => (r.ok ? null : r.json().then((d) => Promise.reject(new Error(d.error)))))
      .then(() => loadOrders())
      .catch((err) => setError(err.message || 'Zmazanie zlyhalo'))
  }

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main sync-page">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <h2 className="dashboard-overview-title">Výrobné príkazy</h2>
        </div>

        <form onSubmit={createOrder} className="sync-filters" style={{ flexDirection: 'column', alignItems: 'stretch', gap: '0.75rem', marginBottom: '1.25rem' }}>
          <strong>Nový príkaz (web)</strong>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', alignItems: 'center' }}>
            <select className="sync-select" value={recipeId} onChange={(e) => setRecipeId(e.target.value)} style={{ minWidth: '220px' }}>
              <option value="">— Receptúra —</option>
              {recipes.map((r) => (
                <option key={r.id} value={r.id}>{r.name || r.finished_product_name || `Recept #${r.id}`}</option>
              ))}
            </select>
            <label style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}>
              Množstvo
              <input className="sync-search" type="text" inputMode="decimal" value={plannedQty} onChange={(e) => setPlannedQty(e.target.value)} style={{ width: '100px' }} />
            </label>
            <label style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}>
              Dátum
              <input className="sync-search" type="date" value={prodDate} onChange={(e) => setProdDate(e.target.value.slice(0, 10))} />
            </label>
            <label style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem' }}>
              <input type="checkbox" checked={requiresApproval} onChange={(e) => setRequiresApproval(e.target.checked)} />
              Vyžaduje schválenie
            </label>
          </div>
          <input className="sync-search" placeholder="Poznámky" value={poNotes} onChange={(e) => setPoNotes(e.target.value)} />
          <button type="submit" className="dashboard-scan-card" style={{ alignSelf: 'flex-start', padding: '0.5rem 1rem' }} disabled={creating}>
            {creating ? 'Ukladám…' : 'Vytvoriť príkaz'}
          </button>
        </form>

        {error ? <p className="customers-error">{error}</p> : null}

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
        ) : filtered.length === 0 ? (
          <div className="sync-empty">
            {orders.length === 0 ? 'Žiadne výrobné príkazy. Vytvorte prvý vyššie.' : 'Žiadne výsledky pre zadaný filter.'}
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
                  </div>
                  <div style={{ marginTop: '0.75rem', display: 'flex', flexWrap: 'wrap', gap: '0.5rem', alignItems: 'center' }}>
                    {o.status === 'draft' && (
                      <>
                        <button type="button" className="dashboard-back" disabled={patching === o.id} onClick={() => patchStatus(o.id, 'pending')}>Odoslať</button>
                        <button type="button" className="dashboard-back" disabled={patching === o.id} onClick={() => patchStatus(o.id, 'approved')}>Schváliť</button>
                        <button type="button" className="dashboard-back" disabled={patching === o.id} onClick={() => patchStatus(o.id, 'in_progress')}>Spustiť výrobu</button>
                        <button type="button" className="dashboard-back" disabled={patching === o.id} onClick={() => deleteOrder(o.id)}>Zmazať</button>
                      </>
                    )}
                    {o.status === 'pending' && (
                      <>
                        <button type="button" className="dashboard-back" disabled={patching === o.id} onClick={() => patchStatus(o.id, 'approved')}>Schváliť</button>
                        <input className="sync-search" placeholder="Dôvod" id={`reject-${o.id}`} style={{ width: '140px' }} />
                        <button type="button" className="dashboard-back" disabled={patching === o.id} onClick={() => {
                          const el = document.getElementById(`reject-${o.id}`)
                          patchStatus(o.id, 'rejected', { rejection_reason: el?.value?.trim() || null })
                          if (el) el.value = ''
                        }}>Zamietnuť</button>
                      </>
                    )}
                    {o.status === 'approved' && (
                      <button type="button" className="dashboard-back" disabled={patching === o.id} onClick={() => patchStatus(o.id, 'in_progress')}>Spustiť výrobu</button>
                    )}
                    {o.status === 'rejected' && (
                      <button type="button" className="dashboard-back" disabled={patching === o.id} onClick={() => deleteOrder(o.id)}>Zmazať</button>
                    )}
                    {(o.status === 'in_progress' || o.status === 'approved') && (
                      <>
                        <input
                          className="sync-search"
                          placeholder="Skutočné množ."
                          style={{ width: '120px' }}
                          id={`complete-qty-${o.id}`}
                        />
                        <label style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem', fontSize: '0.85rem' }}>
                          <input
                            type="checkbox"
                            defaultChecked={autoBatch}
                            id={`auto-batch-${o.id}`}
                          />
                          + šarža
                        </label>
                        <button
                          type="button"
                          className="dashboard-scan-card"
                          style={{ padding: '0.35rem 0.75rem' }}
                          disabled={patching === o.id}
                          onClick={() => {
                            const el = document.getElementById(`complete-qty-${o.id}`)
                            const raw = el?.value?.trim() || ''
                            const aq = raw ? parseFloat(String(raw).replace(',', '.')) : undefined
                            const cb = document.getElementById(`auto-batch-${o.id}`)
                            patchStatus(o.id, 'completed', { actual_quantity: aq, create_batch: !!cb?.checked })
                            if (el) el.value = ''
                          }}
                        >
                          Dokončiť
                        </button>
                      </>
                    )}
                    {['draft', 'pending', 'approved', 'in_progress'].includes(o.status) && (
                      <button type="button" className="dashboard-back" disabled={patching === o.id} onClick={() => patchStatus(o.id, 'cancelled')}>Zrušiť</button>
                    )}
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
