import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import './CustomersPage.css'
import './ProductsPage.css'
import { API_BASE_FOR_CALLS } from '../config'

export default function ProductsPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [products, setProducts] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')

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
    if (!auth) return
    let cancelled = false
    async function fetchProducts() {
      try {
        const url = search.trim()
          ? `${API_BASE_FOR_CALLS}/products?search=${encodeURIComponent(search)}`
          : `${API_BASE_FOR_CALLS}/products`
        const res = await fetch(url, {
          headers: auth?.token ? { Authorization: auth.token } : {},
        })
        if (!res.ok) throw new Error('Načítanie zlyhalo')
        const data = await res.json()
        if (!cancelled) setProducts(Array.isArray(data) ? data : [])
      } catch (e) {
        if (!cancelled) setError(e.message || 'Chyba')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    fetchProducts()
    return () => { cancelled = true }
  }, [auth, search])

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main customers-main">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')} title="Späť na prehľad">← Späť</button>
          <h2 className="dashboard-overview-title">Produkty</h2>
        </div>

        <div className="products-search-wrap">
          <input
            type="search"
            className="products-search"
            placeholder="Hľadať podľa názvu, PLU alebo EAN…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            aria-label="Hľadať produkty"
          />
        </div>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam produkty...</span>
          </div>
        ) : error ? (
          <p className="customers-error">{error}</p>
        ) : products.length === 0 ? (
          <p className="customers-empty">
            Žiadne produkty. Synchronizujte z aplikácie (Domov → Synchronizovať produkty na web).
          </p>
        ) : (
          <ul className="customers-list">
            {products.map((p) => (
              <li key={p.unique_id}>
                <button
                  type="button"
                  className="customers-list-item"
                  onClick={() => navigate(`/dashboard/products/${encodeURIComponent(p.unique_id)}`)}
                >
                  <span className="customers-list-name">{p.name}</span>
                  <span className="customers-list-ico">PLU: {p.plu}</span>
                  {(p.ean || p.qty != null) && (
                    <span className="customers-list-city">
                      {p.ean ? `EAN: ${p.ean}` : ''}
                      {p.ean && p.qty != null ? ' · ' : ''}
                      {p.qty != null ? `Na sklade: ${p.qty} ${p.unit || 'ks'}` : ''}
                    </span>
                  )}
                </button>
              </li>
            ))}
          </ul>
        )}
      </main>
    </div>
  )
}
