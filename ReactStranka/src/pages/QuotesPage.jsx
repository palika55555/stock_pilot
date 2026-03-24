import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { getAuth, getAuthHeaders } from '../utils/auth'
import { apiFetch } from '../utils/apiFetch'
import { API_BASE_FOR_CALLS } from '../config'
import './QuotesPage.css'

const STATUS_LABELS = {
  draft: { label: 'Návrh', cls: 'status--draft' },
  sent: { label: 'Odoslaná', cls: 'status--sent' },
  accepted: { label: 'Prijatá', cls: 'status--accepted' },
  rejected: { label: 'Zamietnutá', cls: 'status--rejected' },
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('sk-SK')
}

function formatEur(v) {
  return new Intl.NumberFormat('sk-SK', { style: 'currency', currency: 'EUR' }).format(Number(v) || 0)
}

export default function QuotesPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [quotes, setQuotes] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [deleting, setDeleting] = useState(null)

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  useEffect(() => {
    if (!auth) return
    let cancelled = false
    setLoading(true)
    const params = new URLSearchParams()
    if (statusFilter) params.set('status', statusFilter)
    if (search.trim()) params.set('search', search.trim())
    fetch(`${API_BASE_FOR_CALLS}/quotes?${params}`, { headers: getAuthHeaders(auth) })
      .then((r) => r.ok ? r.json() : Promise.reject(r.status))
      .then((d) => { if (!cancelled) setQuotes(Array.isArray(d) ? d : []) })
      .catch((e) => { if (!cancelled) setError(`Načítanie zlyhalo (${e})`) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [auth, search, statusFilter])

  const handleDelete = async (id) => {
    if (!window.confirm('Zmazať ponuku?')) return
    setDeleting(id)
    try {
      const r = await fetch(`${API_BASE_FOR_CALLS}/quotes/${id}`, {
        method: 'DELETE', headers: getAuthHeaders(auth),
      })
      if (r.ok) setQuotes((prev) => prev.filter((q) => q.id !== id))
    } catch (_) {}
    setDeleting(null)
  }

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main quotes-main">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <h2 className="dashboard-overview-title">Cenové ponuky</h2>
          <button type="button" className="btn-primary" onClick={() => navigate('/dashboard/quotes/new')}>
            + Nová ponuka
          </button>
        </div>

        <div className="quotes-filters">
          <input
            type="search"
            className="quotes-search"
            placeholder="Hľadať podľa čísla alebo zákazníka…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <select
            className="quotes-status-filter"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="">Všetky stavy</option>
            {Object.entries(STATUS_LABELS).map(([v, { label }]) => (
              <option key={v} value={v}>{label}</option>
            ))}
          </select>
        </div>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam ponuky...</span>
          </div>
        ) : error ? (
          <p className="customers-error">{error}</p>
        ) : quotes.length === 0 ? (
          <div className="quotes-empty">
            <p>Žiadne cenové ponuky.</p>
            <button type="button" className="btn-primary" onClick={() => navigate('/dashboard/quotes/new')}>
              Vytvoriť prvú ponuku
            </button>
          </div>
        ) : (
          <ul className="quotes-list">
            {quotes.map((q) => {
              const st = STATUS_LABELS[q.status] || { label: q.status, cls: '' }
              return (
                <li key={q.id} className="quotes-list-item">
                  <button
                    type="button"
                    className="quotes-list-item__body"
                    onClick={() => navigate(`/dashboard/quotes/${q.id}`)}
                  >
                    <div className="quotes-list-item__top">
                      <span className="quotes-list-item__number">{q.quote_number}</span>
                      <span className={`quotes-status-badge ${st.cls}`}>{st.label}</span>
                    </div>
                    <span className="quotes-list-item__customer">{q.customer_name || '—'}</span>
                    <div className="quotes-list-item__meta">
                      <span>Vystavená: {formatDate(q.issue_date)}</span>
                      <span>Platná do: {formatDate(q.valid_until)}</span>
                      <span className="quotes-list-item__total">{formatEur(q.total_amount)}</span>
                    </div>
                  </button>
                  <button
                    type="button"
                    className="quotes-list-item__delete"
                    title="Zmazať"
                    disabled={deleting === q.id}
                    onClick={() => handleDelete(q.id)}
                  >
                    {deleting === q.id ? <span className="btn-spinner" /> : '×'}
                  </button>
                </li>
              )
            })}
          </ul>
        )}
      </main>
    </div>
  )
}
