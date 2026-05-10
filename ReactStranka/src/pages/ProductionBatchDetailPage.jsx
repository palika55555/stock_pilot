import { useState, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { QRCodeSVG } from 'qrcode.react'
import './DashboardPage.css'
import './CustomersPage.css'
import './ProductionPage.css'
import { getAuth, getAuthHeaders } from '../utils/auth'
import { API_BASE_FOR_CALLS } from '../config'

const QR_PREFIX = 'STOCKPILOT_BATCH:'
const PALLET_STATUSES = ['Na sklade', 'U zákazníka', 'Predané', 'Expedované', 'Rezervované']

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
  const [customers, setCustomers] = useState([])
  const [loading, setLoading] = useState(true)
  const [palletsPieces, setPalletsPieces] = useState('')
  const [palletsCount, setPalletsCount] = useState('')
  const [creatingPallets, setCreatingPallets] = useState(false)
  const [error, setError] = useState('')
  const [palletBusy, setPalletBusy] = useState(null)

  const load = () => {
    if (!auth?.token || !id) return
    const headers = getAuthHeaders(auth)
    Promise.all([
      fetch(`${API_BASE_FOR_CALLS}/batches/${id}`, { headers }).then((r) => (r.ok ? r.json() : null)),
      fetch(`${API_BASE_FOR_CALLS}/batches/${id}/recipe`, { headers }).then((r) => (r.ok ? r.json() : [])),
      fetch(`${API_BASE_FOR_CALLS}/batches/${id}/pallets`, { headers }).then((r) => (r.ok ? r.json() : [])),
      fetch(`${API_BASE_FOR_CALLS}/customers`, { headers }).then((r) => (r.ok ? r.json() : [])),
    ])
      .then(([b, rec, pal, cust]) => {
        setBatch(b || null)
        setRecipe(Array.isArray(rec) ? rec : [])
        setPallets(Array.isArray(pal) ? pal : [])
        setCustomers(Array.isArray(cust) ? cust : [])
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
    const a = getAuth()
    if (!a?.token) {
      navigate('/', { replace: true })
      return
    }
    setAuth(a)
  }, [navigate])

  useEffect(() => {
    if (auth?.token && id) {
      setLoading(true)
      load()
    }
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
    const already = pallets.reduce((s, p) => s + (Number(p.quantity) || 0), 0)
    if (already + qty * count > batch.quantity_produced) {
      setError(`Celkom ${already + qty * count} kusov prevyšuje počet vyrobených (${batch.quantity_produced}).`)
      return
    }
    setError('')
    setCreatingPallets(true)
    fetch(`${API_BASE_FOR_CALLS}/batches/${id}/pallets`, {
      method: 'POST',
      headers: getAuthHeaders(auth),
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

  const updatePallet = (palletId, body) => {
    if (!auth?.token) return
    setPalletBusy(palletId)
    setError('')
    fetch(`${API_BASE_FOR_CALLS}/pallets/${palletId}`, {
      method: 'PUT',
      headers: getAuthHeaders(auth),
      body: JSON.stringify(body),
    })
      .then((r) => (r.ok ? r.json() : r.json().then((d) => Promise.reject(new Error(d.error)))))
      .then(() => load())
      .catch((err) => setError(err.message || 'Chyba'))
      .finally(() => setPalletBusy(null))
  }

  const deletePallet = (palletId) => {
    if (!auth?.token || !window.confirm('Zmazať túto paletu?')) return
    setPalletBusy(palletId)
    fetch(`${API_BASE_FOR_CALLS}/pallets/${palletId}`, { method: 'DELETE', headers: getAuthHeaders(auth) })
      .then((r) => (r.ok ? null : r.json().then((d) => Promise.reject(new Error(d.error)))))
      .then(() => load())
      .catch((err) => setError(err.message || 'Chyba'))
      .finally(() => setPalletBusy(null))
  }

  const deleteBatch = () => {
    if (!auth?.token || !window.confirm('Zmazať celú šaržu vrátane paliet?')) return
    fetch(`${API_BASE_FOR_CALLS}/batches/${id}`, { method: 'DELETE', headers: getAuthHeaders(auth) })
      .then((r) => (r.ok ? null : r.json().then((d) => Promise.reject(new Error(d.error)))))
      .then(() => navigate('/dashboard/production', { replace: true }))
      .catch((err) => setError(err.message || 'Chyba'))
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
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '0.75rem' }}>
          <button type="button" className="dashboard-scan-card" onClick={() => navigate(`/dashboard/production/edit/${batch.id}`)}>Upraviť šaržu</button>
          <button type="button" className="dashboard-back" onClick={deleteBatch}>Zmazať šaržu</button>
        </div>
        <h2 className="dashboard-overview-title">{batch.product_type}</h2>

        <div className="production-detail-qr">
          <QRCodeSVG value={qrPayload} size={200} level="M" includeMargin />
          <p style={{ margin: '0.5rem 0 0 0', fontSize: '0.9rem', color: '#333' }}>QR šarže – skenujte v aplikácii</p>
          <p style={{ margin: '0.25rem 0 0 0', fontSize: '0.85rem', color: '#666' }}>
            Dátum: {formatDate(batch.production_date)} · {batch.quantity_produced} ks
            {batch.requested_m2 != null ? ` · požadované ${Number(batch.requested_m2).toFixed(2)} m²` : ''}
            {batch.actual_stored_m2 != null ? ` · uložené ${Number(batch.actual_stored_m2).toFixed(2)} m²` : ''}
          </p>
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
          <h3 className="dashboard-section-title">Palety a expedícia</h3>
          {pallets.length > 0 ? (
            <ul style={{ listStyle: 'none', padding: 0 }}>
              {pallets.map((p) => (
                <li key={p.id} style={{ border: '1px solid var(--border)', borderRadius: 8, padding: '0.75rem', marginBottom: '0.75rem' }}>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', alignItems: 'center', marginBottom: '0.5rem' }}>
                    <strong>{p.product_type}</strong>
                    <span>{p.quantity} ks</span>
                    <select
                      value={p.status || 'Na sklade'}
                      disabled={palletBusy === p.id}
                      onChange={(e) => updatePallet(p.id, { status: e.target.value })}
                      className="production-date-input"
                    >
                      {PALLET_STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
                    </select>
                  </div>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', alignItems: 'center' }}>
                    <label style={{ fontSize: '0.85rem' }}>
                      Zákazník (pri „U zákazníka“)
                      <select
                        value={p.customer_id ?? ''}
                          disabled={palletBusy === p.id}
                        onChange={(e) => {
                          const v = e.target.value
                          if (v) {
                            updatePallet(p.id, {
                              status: 'U zákazníka',
                              customer_id: parseInt(v, 10),
                            })
                          } else {
                            updatePallet(p.id, { customer_id: null, clear_customer: true, status: 'Na sklade' })
                          }
                        }}
                        style={{ marginLeft: '0.35rem' }}
                      >
                        <option value="">—</option>
                        {customers.map((c) => (
                          <option key={c.id} value={c.id}>{c.name || `Zákazník #${c.id}`}</option>
                        ))}
                      </select>
                    </label>
                    <button type="button" className="dashboard-back" disabled={palletBusy === p.id} onClick={() => updatePallet(p.id, { status: 'Predané', sale_note: p.sale_note || undefined })}>
                      Označiť predané
                    </button>
                    <button type="button" className="dashboard-back" disabled={palletBusy === p.id} onClick={() => deletePallet(p.id)}>Zmazať paletu</button>
                  </div>
                  {(p.sold_at || p.sale_note) && (
                    <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', margin: '0.5rem 0 0 0' }}>
                      {p.sold_at ? `Predaj: ${formatDate(typeof p.sold_at === 'string' ? p.sold_at.slice(0, 10) : p.sold_at)} ` : ''}
                      {p.sale_note || ''}
                    </p>
                  )}
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
                  const allocated = pallets.reduce((s, p) => s + (Number(p.quantity) || 0), 0)
                  const rest = Math.max(0, batch.quantity_produced - allocated)
                  const c = Math.ceil(rest / q)
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
                  const allocated = pallets.reduce((s, p) => s + (Number(p.quantity) || 0), 0)
                  const rest = Math.max(0, batch.quantity_produced - allocated)
                  const q = Math.floor(rest / c)
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
