import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import './CustomersPage.css'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'

export default function WarehousesPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [warehouses, setWarehouses] = useState([])
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
    async function fetchWarehouses() {
      try {
        const res = await fetch(`${API_BASE_FOR_CALLS}/warehouses`, {
          headers: getAuthHeaders(auth),
        })
        if (!res.ok) throw new Error('Načítanie zlyhalo')
        const data = await res.json()
        if (!cancelled) setWarehouses(Array.isArray(data) ? data : [])
      } catch (e) {
        if (!cancelled) setError(e.message || 'Chyba')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    fetchWarehouses()
    return () => { cancelled = true }
  }, [auth])

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main customers-main">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')} title="Späť na prehľad">← Späť</button>
          <h2 className="dashboard-overview-title">Sklady</h2>
        </div>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam sklady...</span>
          </div>
        ) : error ? (
          <p className="customers-error">{error}</p>
        ) : warehouses.length === 0 ? (
          <p className="customers-empty">Zatiaľ nemáte žiadne sklady. Synchronizujte z aplikácie (Nahrať na web).</p>
        ) : (
          <ul className="customers-list">
            {warehouses.map((w) => (
              <li key={w.id}>
                <div className="customers-list-item" style={{ cursor: 'default' }}>
                  <span className="customers-list-name">{w.name}</span>
                  {w.code && <span className="customers-list-ico">Kód: {w.code}</span>}
                  {w.warehouse_type && <span className="customers-list-city">{w.warehouse_type}</span>}
                  {w.city && <span className="customers-list-city">{w.city}</span>}
                  {!w.is_active && <span className="customers-list-inactive">Neaktívny</span>}
                </div>
              </li>
            ))}
          </ul>
        )}
      </main>
    </div>
  )
}
