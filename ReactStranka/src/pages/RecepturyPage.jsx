import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { getAuth, getAuthHeaders } from '../utils/auth'
import { apiFetch } from '../utils/apiFetch'
import { API_BASE_FOR_CALLS } from '../config'
import './sync-pages.css'

function fmtNum(v) {
  return new Intl.NumberFormat('sk-SK', { maximumFractionDigits: 3 }).format(Number(v) || 0)
}

export default function RecepturyPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [recipes, setRecipes] = useState([])
  const [ingredients, setIngredients] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [activeFilter, setActiveFilter] = useState('')
  const [expanded, setExpanded] = useState(null)

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  useEffect(() => {
    if (!auth) return
    let cancelled = false
    setLoading(true)
    fetch(`${API_BASE_FOR_CALLS}/recipes/all`, { headers: getAuthHeaders(auth) })
      .then((r) => r.ok ? r.json() : Promise.reject(r.status))
      .then((d) => {
        if (!cancelled) {
          setRecipes(Array.isArray(d?.recipes) ? d.recipes : [])
          setIngredients(Array.isArray(d?.ingredients) ? d.ingredients : [])
        }
      })
      .catch((e) => { if (!cancelled) setError(`Načítanie zlyhalo (${e})`) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [auth])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return recipes.filter((r) => {
      if (activeFilter === '1' && !r.is_active) return false
      if (activeFilter === '0' && r.is_active) return false
      if (q) {
        const hay = `${r.name} ${r.finished_product_name ?? ''}`.toLowerCase()
        if (!hay.includes(q)) return false
      }
      return true
    })
  }, [recipes, search, activeFilter])

  const getIngredients = (recipeLocalId) =>
    ingredients.filter((i) => i.recipe_local_id === recipeLocalId)

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main sync-page">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <h2 className="dashboard-overview-title">Receptúry</h2>
        </div>

        <div className="sync-readonly-banner">
          ℹ️ Dáta sú synchronizované z Flutter aplikácie. Editácia prebieha v aplikácii.
        </div>

        <div className="sync-filters">
          <input
            type="search"
            className="sync-search"
            placeholder="Hľadať podľa názvu alebo výrobku…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <select className="sync-select" value={activeFilter} onChange={(e) => setActiveFilter(e.target.value)}>
            <option value="">Všetky</option>
            <option value="1">Aktívne</option>
            <option value="0">Neaktívne</option>
          </select>
        </div>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam receptúry...</span>
          </div>
        ) : error ? (
          <p className="customers-error">{error}</p>
        ) : filtered.length === 0 ? (
          <div className="sync-empty">
            {recipes.length === 0
              ? 'Žiadne receptúry. Vytvorte ich v mobilnej aplikácii.'
              : 'Žiadne výsledky pre zadaný filter.'}
          </div>
        ) : (
          <ul className="sync-list">
            {filtered.map((r) => {
              const isExpanded = expanded === r.local_id
              const ings = getIngredients(r.local_id)
              return (
                <li key={r.id} className="sync-list-item" style={{ flexDirection: 'column' }}>
                  <button
                    type="button"
                    className="sync-list-item__body"
                    style={{ width: '100%' }}
                    onClick={() => setExpanded(isExpanded ? null : r.local_id)}
                  >
                    <div className="sync-list-item__top">
                      <span className="sync-list-item__number">{r.name}</span>
                      <span className={`sync-badge ${r.is_active ? 'sync-badge--active' : 'sync-badge--inactive'}`}>
                        {r.is_active ? 'Aktívna' : 'Neaktívna'}
                      </span>
                    </div>
                    <span className="sync-list-item__sub">{r.finished_product_name || '—'}</span>
                    <div className="sync-list-item__meta">
                      <span>Výstup: <span className="sync-list-item__accent">{fmtNum(r.output_quantity)} {r.unit}</span></span>
                      {ings.length > 0 && <span>Suroviny: {ings.length}</span>}
                      {r.note && <span style={{ maxWidth: 260, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.note}</span>}
                      <span style={{ marginLeft: 'auto', opacity: 0.5 }}>{isExpanded ? '▲' : '▼'}</span>
                    </div>
                  </button>
                  {isExpanded && ings.length > 0 && (
                    <div style={{ padding: '0.5rem 1.25rem 0.875rem', borderTop: '1px solid var(--border)' }}>
                      <table style={{ width: '100%', fontSize: '0.85rem', borderCollapse: 'collapse' }}>
                        <thead>
                          <tr style={{ color: 'var(--text-muted)' }}>
                            <th style={{ textAlign: 'left', padding: '0.25rem 0.5rem 0.25rem 0', fontWeight: 500 }}>Surovina</th>
                            <th style={{ textAlign: 'right', padding: '0.25rem 0', fontWeight: 500 }}>Množstvo</th>
                            <th style={{ textAlign: 'left', padding: '0.25rem 0 0.25rem 0.5rem', fontWeight: 500 }}>Jed.</th>
                          </tr>
                        </thead>
                        <tbody>
                          {ings.map((ing) => (
                            <tr key={ing.id}>
                              <td style={{ padding: '0.2rem 0.5rem 0.2rem 0', color: 'var(--text)' }}>{ing.product_name || ing.product_unique_id}</td>
                              <td style={{ textAlign: 'right', padding: '0.2rem 0', color: 'var(--accent)', fontWeight: 600 }}>{fmtNum(ing.quantity)}</td>
                              <td style={{ padding: '0.2rem 0 0.2rem 0.5rem', color: 'var(--text-muted)' }}>{ing.unit}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </li>
              )
            })}
          </ul>
        )}
      </main>
    </div>
  )
}
