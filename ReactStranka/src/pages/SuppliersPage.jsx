import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import './CustomersPage.css'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'

export default function SuppliersPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [suppliers, setSuppliers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) {
      navigate('/', { replace: true })
      return
    }
    setAuth(a)
  }, [navigate])

  useEffect(() => {
    if (!auth) return
    let cancelled = false
    async function fetchSuppliers() {
      try {
        const res = await fetch(`${API_BASE_FOR_CALLS}/suppliers`, {
          headers: getAuthHeaders(auth),
        })
        if (!res.ok) throw new Error('Načítanie zlyhalo')
        const data = await res.json()
        if (!cancelled) setSuppliers(Array.isArray(data) ? data : [])
      } catch (e) {
        if (!cancelled) setError(e.message || 'Chyba')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    fetchSuppliers()
    return () => { cancelled = true }
  }, [auth])

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main customers-main">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')} title="Späť na prehľad">← Späť</button>
          <h2 className="dashboard-overview-title">Dodávatelia</h2>
        </div>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam dodávateľov...</span>
          </div>
        ) : error ? (
          <p className="customers-error">{error}</p>
        ) : suppliers.length === 0 ? (
          <p className="customers-empty">Zatiaľ nemáte žiadnych dodávateľov. Synchronizujte z aplikácie (Nahrať na web).</p>
        ) : (
          <ul className="customers-list">
            {suppliers.map((s) => (
              <li key={s.id}>
                <div className="customers-list-item" style={{ cursor: 'default' }}>
                  <span className="customers-list-name">{s.name}</span>
                  <span className="customers-list-ico">IČO: {s.ico}</span>
                  {s.city && <span className="customers-list-city">{s.city}</span>}
                  {!s.is_active && <span className="customers-list-inactive">Neaktívny</span>}
                </div>
              </li>
            ))}
          </ul>
        )}
      </main>
    </div>
  )
}
