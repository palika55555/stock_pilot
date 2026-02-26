import { useState, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import './DashboardPage.css'
import './CustomerDetailPage.css'

const API_BASE = import.meta.env.VITE_API_URL || 'https://backend.stockpilot.sk'

function DetailRow({ label, value }) {
  if (value == null || value === '') return null
  return (
    <div className="customer-detail-row">
      <dt className="customer-detail-label">{label}</dt>
      <dd className="customer-detail-value">{value}</dd>
    </div>
  )
}

export default function CustomerDetailPage() {
  const navigate = useNavigate()
  const { id } = useParams()
  const [auth, setAuth] = useState(null)
  const [customer, setCustomer] = useState(null)
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
    if (!auth || !id) return
    let cancelled = false
    async function fetchCustomer() {
      try {
        const res = await fetch(`${API_BASE}/api/customers/${id}`, {
          headers: auth?.token ? { Authorization: `Bearer ${auth.token}` } : {},
        })
        if (res.status === 404) {
          if (!cancelled) setError('Zákazník nebol nájdený')
          return
        }
        if (!res.ok) throw new Error('Načítanie zlyhalo')
        const data = await res.json()
        if (!cancelled) setCustomer(data)
      } catch (e) {
        if (!cancelled) setError(e.message || 'Chyba')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    fetchCustomer()
    return () => { cancelled = true }
  }, [auth, id])

  if (!auth) return null

  return (
    <div className="dashboard-page">
      <header className="dashboard-header">
        <div className="dashboard-brand">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard/customers')} title="Späť na zákazníkov">
            ←
          </button>
          <span className="dashboard-logo-label">STOCK</span>
          <h1 className="dashboard-logo-title">PILOT</h1>
        </div>
        <div className="dashboard-user">
          <span className="dashboard-user-name">{auth.user?.fullName || auth.user?.username || 'Používateľ'}</span>
          <button type="button" className="btn-logout" onClick={() => { localStorage.removeItem('stockpilot_auth'); navigate('/', { replace: true }) }}>
            Odhlásiť sa
          </button>
        </div>
      </header>

      <main className="dashboard-main customer-detail-main">
        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam...</span>
          </div>
        ) : error ? (
          <p className="customer-detail-error">{error}</p>
        ) : customer ? (
          <>
            <div className="customer-detail-header">
              <h2 className="dashboard-overview-title">{customer.name}</h2>
              <button type="button" className="btn-back-list" onClick={() => navigate('/dashboard/customers')}>
                Späť na zoznam
              </button>
            </div>

            <dl className="customer-detail-dl">
              <DetailRow label="IČO" value={customer.ico} />
              <DetailRow label="Email" value={customer.email} />
              <DetailRow label="Adresa" value={customer.address} />
              <DetailRow label="Mesto" value={customer.city} />
              <DetailRow label="PSČ" value={customer.postal_code} />
              <DetailRow label="DIČ" value={customer.dic} />
              <DetailRow label="IČ DPH" value={customer.ic_dph} />
              <div className="customer-detail-row">
                <dt className="customer-detail-label">Predvolená DPH %</dt>
                <dd className="customer-detail-value">{customer.default_vat_rate ?? 20} %</dd>
              </div>
              <div className="customer-detail-row">
                <dt className="customer-detail-label">Stav</dt>
                <dd className="customer-detail-value">{customer.is_active === 1 ? 'Aktívny' : 'Neaktívny'}</dd>
              </div>
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
