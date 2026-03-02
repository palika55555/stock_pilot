import { useState, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { QRCodeSVG } from 'qrcode.react'
import './DashboardPage.css'
import './CustomersPage.css'
import './ProductionPage.css'
import { API_BASE_FOR_CALLS } from '../config'

const QR_PREFIX = 'STOCKPILOT_BATCH:'

function formatDate(d) {
  if (!d) return ''
  const x = typeof d === 'string' ? d.slice(0, 10) : d
  const [y, m, day] = x.split('-')
  return `${parseInt(day, 10)}. ${parseInt(m, 10)}. ${y}`
}

export default function ProductionBatchDetailPage() {
  const navigate = useNavigate()
  const { id } = useParams()
  const [auth, setAuth] = useState(null)
  const [batch, setBatch] = useState(null)
  const [recipe, setRecipe] = useState([])
  const [pallets, setPallets] = useState([])
  const [loading, setLoading] = useState(true)
  const [palletsPieces, setPalletsPieces] = useState('')
  const [palletsCount, setPalletsCount] = useState('')
  const [creatingPallets, setCreatingPallets] = useState(false)
  const [error, setError] = useState('')

  const load = () => {
    if (!auth?.token || !id) return
    Promise.all([
      fetch(`${API_BASE_FOR_CALLS}/batches/${id}`, { headers: { Authorization: auth.token } }).then((r) => (r.ok ? r.json() : null)),
      fetch(`${API_BASE_FOR_CALLS}/batches/${id}/recipe`, { headers: { Authorization: auth.token } }).then((r) => (r.ok ? r.json() : [])),
      fetch(`${API_BASE_FOR_CALLS}/batches/${id}/pallets`, { headers: { Authorization: auth.token } }).then((r) => (r.ok ? r.json() : [])),
    ])
      .then(([b, rec, pal]) => {
        setBatch(b || null)
        setRecipe(Array.isArray(rec) ? rec : [])
        setPallets(Array.isArray(pal) ? pal : [])
        if (b && !palletsPieces && !palletsCount) {
          const total = b.quantity_produced || 0
          const defaultCount = Math.min(5, total) || 1
          const defaultQty = total ? Math.floor(total / defaultCount) : 1
          setPalletsCount(String(defaultCount))
          setPalletsPieces(String(defaultQty))
        }
      })
      .catch(() => setBatch(null))
      .finally(() => setLoading(false))
  }

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
    if (auth?.token && id) load()
  }, [auth?.token, id])

  const handleCreatePallets = (e) => {
    e.preventDefault()
    if (!auth?.token || !batch) return
    const qty = parseInt(palletsPieces, 10)
    const count = parseInt(palletsCount, 10)
    if (Number.isNaN(qty) || qty <= 0 || Number.isNaN(count) || count <= 0) {
      setError('Zadajte platný počet kusov na paletu a počet paliet.')
      return
    }
    if (qty * count > batch.quantity_produced) {
      setError(`Celkom ${qty * count} kusov prevyšuje počet vyrobených (${batch.quantity_produced}).`)
      return
    }
    setError('')
    setCreatingPallets(true)
    fetch(`${API_BASE_FOR_CALLS}/batches/${id}/pallets`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: auth.token,
      },
      body: JSON.stringify({ pieces_per_pallet: qty, count }),
    })
      .then((r) => {
        if (!r.ok) return r.json().then((d) => { throw new Error(d.error || 'Chyba') })
        return r.json()
      })
      .then(() => {
        setPalletsPieces('')
        setPalletsCount('')
        load()
      })
      .catch((err) => setError(err.message || 'Chyba'))
      .finally(() => setCreatingPallets(false))
  }

  if (!auth) return null
  if (loading || !batch) {
    return (
      <div className="dashboard-page-content">
        <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard/production')} style={{ marginBottom: '0.5rem' }}>← Späť</button>
        <main className="dashboard-main">
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>{batch === null && !loading ? 'Šarža nebola nájdená' : 'Načítavam...'}</span>
          </div>
        </main>
      </div>
    )
  }

  const qrPayload = `${QR_PREFIX}${batch.id}`

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main customers-main">
        <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard/production')} style={{ marginBottom: '0.5rem' }}>← Späť na výrobu</button>
        <h2 className="dashboard-overview-title">{batch.product_type}</h2>

        <div className="production-detail-qr">
          <QRCodeSVG value={qrPayload} size={200} level="M" includeMargin />
          <p style={{ margin: '0.5rem 0 0 0', fontSize: '0.9rem', color: '#333' }}>QR šarže – skenujte v aplikácii</p>
          <p style={{ margin: '0.25rem 0 0 0', fontSize: '0.85rem', color: '#666' }}>Dátum: {formatDate(batch.production_date)} · {batch.quantity_produced} ks</p>
        </div>

        {batch.notes && (
          <p className="production-detail-notes" style={{ marginTop: '1rem', color: 'var(--text-muted)' }}>
            Poznámky: {batch.notes}
          </p>
        )}

        {recipe.length > 0 && (
          <div className="production-detail-recipe">
            <h3 className="dashboard-section-title">Receptúra</h3>
            <ul>
              {recipe.map((r) => (
                <li key={r.id}>
                  <span>{r.material_name}</span>
                  <span>{r.quantity} {r.unit}</span>
                </li>
              ))}
            </ul>
          </div>
        )}

        <div className="production-detail-pallets">
          <h3 className="dashboard-section-title">Palety z tejto šarže</h3>
          {pallets.length > 0 ? (
            <ul>
              {pallets.map((p) => (
                <li key={p.id}>
                  <span>{p.product_type} – {p.quantity} ks</span>
                  <span>{p.status}</span>
                </li>
              ))}
            </ul>
          ) : (
            <p style={{ color: 'var(--text-muted)', marginTop: '0.5rem' }}>Zatiaľ žiadne palety.</p>
          )}

          <form onSubmit={handleCreatePallets} className="production-create-pallets-form">
            <label>Počet kusov na jednu paletu</label>
            <input
              type="number"
              min="1"
              value={palletsPieces}
              onChange={(e) => {
                setPalletsPieces(e.target.value)
                const q = parseInt(e.target.value, 10)
                if (!Number.isNaN(q) && q > 0 && batch) {
                  const c = Math.ceil(batch.quantity_produced / q)
                  setPalletsCount(String(Math.max(1, c)))
                }
              }}
            />
            <label>Počet paliet</label>
            <input
              type="number"
              min="1"
              value={palletsCount}
              onChange={(e) => {
                setPalletsCount(e.target.value)
                const c = parseInt(e.target.value, 10)
                if (!Number.isNaN(c) && c > 0 && batch) {
                  const q = Math.floor(batch.quantity_produced / c)
                  setPalletsPieces(String(Math.max(1, q)))
                }
              }}
            />
            {error && <p style={{ color: '#f87171', fontSize: '0.9rem' }}>{error}</p>}
            <button type="submit" disabled={creatingPallets}>
              {creatingPallets ? 'Vytváram...' : 'Vytvoriť palety'}
            </button>
          </form>
        </div>
      </main>
    </div>
  )
}
