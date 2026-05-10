import { useState, useEffect, useMemo } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { QRCodeSVG } from 'qrcode.react'
import './DashboardPage.css'
import './CustomersPage.css'
import './ProductionPage.css'
import { getAuth, getAuthHeaders } from '../utils/auth'
import { API_BASE_FOR_CALLS } from '../config'

const QR_PREFIX = 'STOCKPILOT_BATCH:'
const PALLET_STATUSES = ['Na sklade', 'U zákazníka', 'Predané', 'Expedované', 'Rezervované']

function statusClass(status) {
  if (status === 'Na sklade') return 'is-stock'
  if (status === 'U zákazníka') return 'is-cust'
  if (status === 'Predané' || status === 'Expedované') return 'is-sold'
  return 'is-other'
}

function formatDate(d) {
  if (!d) return ''
  const x = typeof d === 'string' ? d.slice(0, 10) : new Date(d).toISOString().slice(0, 10)
  const [y, m, day] = x.split('-')
  return `${parseInt(day, 10)}. ${parseInt(m, 10)}. ${y}`
}

function todayStr() {
  return new Date().toISOString().slice(0, 10)
}

function fmtNum(v, dec = 0) {
  return new Intl.NumberFormat('sk-SK', { minimumFractionDigits: 0, maximumFractionDigits: dec }).format(Number(v) || 0)
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
  const [selectedIds, setSelectedIds] = useState(new Set())
  const [saleOpen, setSaleOpen] = useState(false)
  const [saleStatus, setSaleStatus] = useState('Predané')
  const [saleCustomerId, setSaleCustomerId] = useState('')
  const [saleDate, setSaleDate] = useState(todayStr())
  const [saleNote, setSaleNote] = useState('')
  const [saleBusy, setSaleBusy] = useState(false)

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

  const allocated = useMemo(() => pallets.reduce((s, p) => s + (Number(p.quantity) || 0), 0), [pallets])
  const onStock = useMemo(() => pallets.filter((p) => p.status === 'Na sklade').reduce((s, p) => s + (Number(p.quantity) || 0), 0), [pallets])
  const atCustomer = useMemo(() => pallets.filter((p) => p.status === 'U zákazníka').reduce((s, p) => s + (Number(p.quantity) || 0), 0), [pallets])
  const sold = useMemo(() => pallets.filter((p) => p.status === 'Predané' || p.status === 'Expedované').reduce((s, p) => s + (Number(p.quantity) || 0), 0), [pallets])
  const free = useMemo(() => Math.max(0, (batch?.quantity_produced || 0) - allocated), [batch, allocated])

  useEffect(() => {
    if (!batch || palletsPieces || palletsCount) return
    const total = free
    if (total <= 0) return
    const defaultCount = Math.min(5, total) || 1
    const defaultQty = Math.max(1, Math.floor(total / defaultCount))
    setPalletsCount(String(defaultCount))
    setPalletsPieces(String(defaultQty))
  }, [batch, free])

  const toggleSelected = (palletId) => {
    setSelectedIds((prev) => {
      const next = new Set(prev)
      if (next.has(palletId)) next.delete(palletId)
      else next.add(palletId)
      return next
    })
  }

  const allSelectableIds = useMemo(() => pallets.map((p) => p.id), [pallets])
  const allSelected = selectedIds.size > 0 && selectedIds.size === allSelectableIds.length

  const toggleAll = () => {
    if (allSelected) setSelectedIds(new Set())
    else setSelectedIds(new Set(allSelectableIds))
  }

  const selectedSummary = useMemo(() => {
    const arr = pallets.filter((p) => selectedIds.has(p.id))
    return { count: arr.length, pieces: arr.reduce((s, p) => s + (Number(p.quantity) || 0), 0) }
  }, [pallets, selectedIds])

  const handleCreatePallets = (e) => {
    e.preventDefault()
    if (!auth?.token || !batch) return
    const qty = parseInt(palletsPieces, 10)
    const count = parseInt(palletsCount, 10)
    if (Number.isNaN(qty) || qty <= 0 || Number.isNaN(count) || count <= 0) {
      setError('Zadajte platný počet kusov na paletu a počet paliet.')
      return
    }
    if (allocated + qty * count > batch.quantity_produced) {
      setError(`Celkom ${allocated + qty * count} kusov prevyšuje počet vyrobených (${batch.quantity_produced}).`)
      return
    }
    setError('')
    setCreatingPallets(true)
    fetch(`${API_BASE_FOR_CALLS}/batches/${id}/pallets`, {
      method: 'POST',
      headers: getAuthHeaders(auth),
      body: JSON.stringify({ pieces_per_pallet: qty, count }),
    })
      .then((r) => (r.ok ? r.json() : r.json().then((d) => Promise.reject(new Error(d.error || 'Chyba')))))
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
      .then(() => {
        setSelectedIds((prev) => { const n = new Set(prev); n.delete(palletId); return n })
        load()
      })
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

  const submitBulkSale = (e) => {
    e.preventDefault()
    if (!auth?.token || selectedIds.size === 0) return
    const wantsCust = saleStatus === 'U zákazníka'
    if (wantsCust && !saleCustomerId) {
      setError('Vyberte zákazníka pre status „U zákazníka“.')
      return
    }
    setSaleBusy(true)
    setError('')
    fetch(`${API_BASE_FOR_CALLS}/pallets/bulk-sell`, {
      method: 'POST',
      headers: getAuthHeaders(auth),
      body: JSON.stringify({
        ids: [...selectedIds],
        status: saleStatus,
        customer_id: wantsCust ? parseInt(saleCustomerId, 10) : null,
        sale_note: saleNote.trim() || null,
        sold_at: saleDate || null,
      }),
    })
      .then((r) => (r.ok ? r.json() : r.json().then((d) => Promise.reject(new Error(d.error)))))
      .then(() => {
        setSaleOpen(false)
        setSelectedIds(new Set())
        setSaleNote('')
        load()
      })
      .catch((err) => setError(err.message || 'Hromadná akcia zlyhala'))
      .finally(() => setSaleBusy(false))
  }

  if (!auth) return null

  if (loading || !batch) {
    return (
      <div className="dashboard-page-content production-page-wrap">
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

  const total = batch.quantity_produced || 0
  const pct = (n) => (total > 0 ? Math.max(0, Math.min(100, (n / total) * 100)) : 0)
  const margin = batch.revenue_total != null && batch.cost_total != null && batch.revenue_total > 0
    ? ((Number(batch.revenue_total) - Number(batch.cost_total)) / Number(batch.revenue_total)) * 100
    : null

  const qrPayload = `${QR_PREFIX}${batch.id}`

  return (
    <div className="dashboard-page-content production-page-wrap">
      <main className="dashboard-main customers-main">
        <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard/production')} style={{ marginBottom: '0.5rem' }}>← Späť na výrobu</button>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '0.75rem' }}>
          <button type="button" className="dashboard-scan-card" onClick={() => navigate(`/dashboard/production/edit/${batch.id}`)}>Upraviť šaržu</button>
          <button type="button" className="dashboard-back" onClick={deleteBatch}>Zmazať šaržu</button>
        </div>
        <h2 className="dashboard-overview-title">{batch.product_type}</h2>

        <div className="prod-summary-grid">
          <div className="prod-summary-card">
            <h4>Vyrobené</h4>
            <div className="num">{fmtNum(total)} ks</div>
            <span className="sub">{formatDate(batch.production_date)}</span>
          </div>
          {(batch.requested_m2 != null || batch.actual_stored_m2 != null) && (
            <div className="prod-summary-card">
              <h4>Plocha (m²)</h4>
              <div className="num">{fmtNum(batch.actual_stored_m2 ?? batch.requested_m2, 2)}</div>
              <span className="sub">
                {batch.requested_m2 != null ? `požadované ${fmtNum(batch.requested_m2, 2)} m²` : ''}
              </span>
            </div>
          )}
          <div className="prod-summary-card">
            <h4>Voľné kusy</h4>
            <div className="num">{fmtNum(free)}</div>
            <span className="sub">{fmtNum(allocated)} z {fmtNum(total)} na paletách</span>
          </div>
          <div className="prod-summary-card">
            <h4>Predané</h4>
            <div className="num">{fmtNum(sold)}</div>
            <span className="sub">{fmtNum(onStock)} sklad · {fmtNum(atCustomer)} u zákazníka</span>
          </div>
          {(batch.cost_total != null || batch.revenue_total != null) && (
            <div className="prod-summary-card">
              <h4>Ekonomika</h4>
              <div className="num">{margin != null ? `${margin.toFixed(1)} %` : '—'}</div>
              <span className="sub">
                náklady {batch.cost_total != null ? `${fmtNum(batch.cost_total, 2)} €` : '—'} ·
                výnos {batch.revenue_total != null ? `${fmtNum(batch.revenue_total, 2)} €` : '—'}
              </span>
            </div>
          )}
        </div>

        <div className="prod-progress" title={`${fmtNum(allocated)} / ${fmtNum(total)} ks`}>
          <span className="is-stock" style={{ width: `${pct(onStock)}%` }} />
          <span className="is-cust" style={{ width: `${pct(atCustomer)}%` }} />
          <span className="is-sold" style={{ width: `${pct(sold)}%` }} />
          <span className="is-free" style={{ width: `${pct(free)}%` }} />
        </div>
        <div className="prod-legend" style={{ marginBottom: '1.25rem' }}>
          <span><i className="is-stock" />Sklad {fmtNum(onStock)}</span>
          <span><i className="is-cust" />U zákazníka {fmtNum(atCustomer)}</span>
          <span><i className="is-sold" />Predané {fmtNum(sold)}</span>
          <span><i className="is-free" />Voľné {fmtNum(free)}</span>
        </div>

        <div className="production-detail-qr">
          <QRCodeSVG value={qrPayload} size={160} level="M" includeMargin />
          <p style={{ margin: '0.5rem 0 0 0', fontSize: '0.85rem', color: '#333' }}>QR šarže pre skenovanie v aplikácii</p>
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
            <>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', alignItems: 'center', marginBottom: '0.75rem' }}>
                <label style={{ display: 'inline-flex', alignItems: 'center', gap: '0.4rem' }}>
                  <input type="checkbox" checked={allSelected} onChange={toggleAll} />
                  Vybrať všetky ({selectedSummary.count}/{pallets.length})
                </label>
                {selectedSummary.count > 0 && (
                  <>
                    <span style={{ color: 'var(--text-muted)' }}>{fmtNum(selectedSummary.pieces)} ks vybraných</span>
                    <button type="button" className="dashboard-scan-card" style={{ padding: '0.4rem 0.9rem' }} onClick={() => setSaleOpen(true)}>
                      Hromadne predať / priradiť
                    </button>
                    <button type="button" className="dashboard-back" onClick={() => setSelectedIds(new Set())}>Zrušiť výber</button>
                  </>
                )}
              </div>

              <ul style={{ listStyle: 'none', padding: 0 }}>
                {pallets.map((p) => {
                  const sCls = statusClass(p.status)
                  const cust = customers.find((c) => c.id === p.customer_id)
                  return (
                    <li key={p.id} className={`prod-pallet-card ${sCls}`}>
                      <div className="row">
                        <input
                          type="checkbox"
                          checked={selectedIds.has(p.id)}
                          onChange={() => toggleSelected(p.id)}
                          aria-label="Vybrať paletu"
                        />
                        <strong>Paleta #{p.id}</strong>
                        <span>{fmtNum(p.quantity)} ks</span>
                        <span className={`prod-pallet-status ${sCls}`}>{p.status || 'Na sklade'}</span>
                        {p.sold_at && <span style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>predaj: {formatDate(p.sold_at)}</span>}
                        {cust && <span style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>· {cust.name}</span>}
                      </div>
                      <div className="row">
                        <select
                          className="production-date-input"
                          value={p.status || 'Na sklade'}
                          disabled={palletBusy === p.id}
                          onChange={(e) => updatePallet(p.id, { status: e.target.value })}
                          style={{ minWidth: 150 }}
                        >
                          {PALLET_STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
                        </select>
                        <select
                          className="production-date-input"
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
                          style={{ minWidth: 180 }}
                        >
                          <option value="">— bez zákazníka —</option>
                          {customers.map((c) => (
                            <option key={c.id} value={c.id}>{c.name || `Zákazník #${c.id}`}</option>
                          ))}
                        </select>
                        <button type="button" className="dashboard-back" disabled={palletBusy === p.id} onClick={() => updatePallet(p.id, { status: 'Predané' })}>
                          Predané
                        </button>
                        <button type="button" className="dashboard-back" disabled={palletBusy === p.id} onClick={() => deletePallet(p.id)}>Zmazať</button>
                      </div>
                      {p.sale_note && (
                        <div className="row" style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>
                          📝 {p.sale_note}
                        </div>
                      )}
                    </li>
                  )
                })}
              </ul>
            </>
          ) : (
            <p style={{ color: 'var(--text-muted)', marginTop: '0.5rem' }}>Zatiaľ žiadne palety.</p>
          )}

          {free > 0 && (
            <form onSubmit={handleCreatePallets} className="production-create-pallets-form">
              <strong>Vytvoriť ďalšie palety (voľných {fmtNum(free)} ks)</strong>
              <label style={{ marginTop: '0.5rem' }}>Počet kusov na jednu paletu</label>
              <input
                type="number"
                min="1"
                value={palletsPieces}
                onChange={(e) => {
                  setPalletsPieces(e.target.value)
                  const q = parseInt(e.target.value, 10)
                  if (!Number.isNaN(q) && q > 0) {
                    const c = Math.ceil(free / q)
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
                  if (!Number.isNaN(c) && c > 0) {
                    const q = Math.floor(free / c)
                    setPalletsPieces(String(Math.max(1, q)))
                  }
                }}
              />
              {error && <p style={{ color: '#f87171', fontSize: '0.9rem' }}>{error}</p>}
              <button type="submit" disabled={creatingPallets}>
                {creatingPallets ? 'Vytváram...' : 'Vytvoriť palety'}
              </button>
            </form>
          )}
          {free === 0 && error && <p style={{ color: '#f87171', fontSize: '0.9rem' }}>{error}</p>}
        </div>

        {saleOpen && (
          <div
            role="dialog"
            aria-modal="true"
            style={{
              position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000,
            }}
            onClick={(e) => { if (e.target === e.currentTarget) setSaleOpen(false) }}
          >
            <form
              onSubmit={submitBulkSale}
              className="production-create-pallets-form"
              style={{ width: 'min(420px, 92vw)', margin: 0 }}
            >
              <h3 style={{ marginTop: 0 }}>Hromadná akcia ({selectedSummary.count} paliet · {fmtNum(selectedSummary.pieces)} ks)</h3>
              <label>Status</label>
              <select className="production-date-input" value={saleStatus} onChange={(e) => setSaleStatus(e.target.value)} style={{ width: '100%' }}>
                {PALLET_STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
              </select>
              {saleStatus === 'U zákazníka' && (
                <>
                  <label>Zákazník</label>
                  <select className="production-date-input" value={saleCustomerId} onChange={(e) => setSaleCustomerId(e.target.value)} style={{ width: '100%' }}>
                    <option value="">— vyberte zákazníka —</option>
                    {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                  </select>
                </>
              )}
              {(saleStatus === 'Predané' || saleStatus === 'Expedované') && (
                <>
                  <label>Dátum predaja / expedície</label>
                  <input type="date" value={saleDate} onChange={(e) => setSaleDate(e.target.value.slice(0, 10))} />
                </>
              )}
              <label>Poznámka (faktúra, číslo dokladu…)</label>
              <input type="text" value={saleNote} onChange={(e) => setSaleNote(e.target.value)} placeholder="napr. FA 2026/1234" />
              {error && <p style={{ color: '#f87171', fontSize: '0.9rem' }}>{error}</p>}
              <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem' }}>
                <button type="submit" disabled={saleBusy}>{saleBusy ? 'Ukladám…' : 'Použiť'}</button>
                <button type="button" className="dashboard-back" onClick={() => setSaleOpen(false)} disabled={saleBusy}>Zrušiť</button>
              </div>
            </form>
          </div>
        )}
      </main>
    </div>
  )
}
