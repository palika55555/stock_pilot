import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'
import './sync-pages.css'

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('sk-SK')
}

function fmtNum(v, dec = 2) {
  return new Intl.NumberFormat('sk-SK', { minimumFractionDigits: dec, maximumFractionDigits: dec }).format(Number(v) || 0)
}

function fmtEur(v) {
  return new Intl.NumberFormat('sk-SK', { style: 'currency', currency: 'EUR' }).format(Number(v) || 0)
}

export default function TransportyPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [transports, setTransports] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  useEffect(() => {
    if (!auth) return
    let cancelled = false
    setLoading(true)
    fetch(`${API_BASE_FOR_CALLS}/transports/all`, { headers: getAuthHeaders(auth) })
      .then((r) => r.ok ? r.json() : Promise.reject(r.status))
      .then((d) => { if (!cancelled) setTransports(Array.isArray(d?.transports) ? d.transports : []) })
      .catch((e) => { if (!cancelled) setError(`Načítanie zlyhalo (${e})`) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [auth])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return transports
    return transports.filter((t) => {
      const hay = `${t.origin ?? ''} ${t.destination ?? ''}`.toLowerCase()
      return hay.includes(q)
    })
  }, [transports, search])

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main sync-page">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <h2 className="dashboard-overview-title">Transporty</h2>
        </div>

        <div className="sync-readonly-banner">
          ℹ️ Dáta sú synchronizované z Flutter aplikácie. Editácia prebieha v aplikácii.
        </div>

        <div className="sync-filters">
          <input
            type="search"
            className="sync-search"
            placeholder="Hľadať podľa miesta odchodu alebo destinácie…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam transporty...</span>
          </div>
        ) : error ? (
          <p className="customers-error">{error}</p>
        ) : filtered.length === 0 ? (
          <div className="sync-empty">
            {transports.length === 0
              ? 'Žiadne transporty. Vypočítajte ich v mobilnej aplikácii.'
              : 'Žiadne výsledky pre zadaný filter.'}
          </div>
        ) : (
          <ul className="sync-list">
            {filtered.map((t) => (
              <li key={t.id} className="sync-list-item">
                <div className="sync-list-item__body">
                  <div className="sync-list-item__top">
                    <span className="sync-list-item__number">
                      {t.origin || '?'} → {t.destination || '?'}
                    </span>
                    {t.is_round_trip ? (
                      <span className="sync-badge sync-badge--blue">Spiatočná</span>
                    ) : (
                      <span className="sync-badge sync-badge--gray">Jednosmerná</span>
                    )}
                  </div>
                  <div className="sync-list-item__meta">
                    <span>Vzdialenosť: <span className="sync-list-item__accent">{fmtNum(t.distance, 1)} km</span></span>
                    <span>Celkové náklady: <span className="sync-list-item__accent">{fmtEur(t.total_cost)}</span></span>
                    {Number(t.fuel_cost) > 0 && <span>Palivo: {fmtEur(t.fuel_cost)}</span>}
                    <span>Dátum: {fmtDate(t.created_at)}</span>
                    {t.notes && <span style={{ maxWidth: 260, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t.notes}</span>}
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
