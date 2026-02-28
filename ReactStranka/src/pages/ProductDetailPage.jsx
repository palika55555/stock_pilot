import { useState, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import './DashboardPage.css'
import './ProductDetailPage.css'
import { API_BASE_FOR_CALLS } from '../config'

function DetailRow({ label, value }) {
  if (value == null || value === '') return null
  return (
    <div className="product-detail-row">
      <dt className="product-detail-label">{label}</dt>
      <dd className="product-detail-value">{value}</dd>
    </div>
  )
}

export default function ProductDetailPage() {
  const navigate = useNavigate()
  const { uniqueId } = useParams()
  const [auth, setAuth] = useState(null)
  const [product, setProduct] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

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
    if (!auth || !uniqueId) return
    let cancelled = false
    async function fetchProduct() {
      try {
        const res = await fetch(
          `${API_BASE_FOR_CALLS}/products/${encodeURIComponent(uniqueId)}`,
          { headers: auth?.token ? { Authorization: auth.token } : {} }
        )
        if (res.status === 404) {
          if (!cancelled) setError('Produkt nebol nájdený')
          return
        }
        if (!res.ok) throw new Error('Načítanie zlyhalo')
        const data = await res.json()
        if (!cancelled) setProduct(data)
      } catch (e) {
        if (!cancelled) setError(e.message || 'Chyba')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    fetchProduct()
    return () => { cancelled = true }
  }, [auth, uniqueId])

  const handleLogout = () => {
    localStorage.removeItem('stockpilot_auth')
    navigate('/', { replace: true })
  }

  if (!auth) return null

  return (
    <div className="dashboard-page">
      <header className="dashboard-header">
        <div className="dashboard-brand">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')} title="Späť na prehľad">
            ←
          </button>
          <span className="dashboard-logo-label">STOCK</span>
          <h1 className="dashboard-logo-title">PILOT</h1>
        </div>
        <div className="dashboard-user">
          <span className="dashboard-user-name">{auth.user?.fullName || auth.user?.username || 'Používateľ'}</span>
          <span className="dashboard-user-role">{auth.user?.role || 'user'}</span>
          <button type="button" className="btn-logout" onClick={handleLogout}>
            Odhlásiť sa
          </button>
        </div>
      </header>

      <main className="dashboard-main product-detail-main">
        <h2 className="dashboard-overview-title">Detail produktu</h2>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam...</span>
          </div>
        ) : error ? (
          <p className="product-detail-error">{error}</p>
        ) : product ? (
          <>
            <div className="product-detail-header">
              <button
                type="button"
                className="btn-back-list"
                onClick={() => navigate('/dashboard/products')}
              >
                ← Späť na zoznam
              </button>
            </div>

            <dl className="product-detail-dl">
              <DetailRow label="Názov" value={product.name} />
              <DetailRow label="PLU" value={product.plu} />
              <DetailRow label="EAN / Čiarový kód" value={product.ean} />
              <DetailRow label="Jednotka" value={product.unit || 'ks'} />
              <DetailRow
                label="Na sklade"
                value={product.qty != null ? `${product.qty} ${product.unit || 'ks'}` : null}
              />
              <DetailRow label="Identifikátor" value={product.unique_id} />
            </dl>
          </>
        ) : null}
      </main>

      <footer className="dashboard-footer">
        Stock Pilot &copy; {new Date().getFullYear()}
      </footer>
    </div>
  )
}
