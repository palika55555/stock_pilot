import { useState, useEffect, useRef } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'
import './QuotesPage.css'
import './QuoteFormPage.css'

const ITEM_TYPES = ['Tovar', 'Paleta', 'Doprava', 'Iné']
const VAT_RATES = [0, 5, 10, 20]

function genId() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2)
}

function formatEur(v) {
  return new Intl.NumberFormat('sk-SK', { style: 'currency', currency: 'EUR' }).format(Number(v) || 0)
}

function calcItemTotal(item, pricesIncludeVat) {
  const base = (Number(item.qty) || 0) * (Number(item.unit_price) || 0)
  const disc = base * (Number(item.discount_percent) / 100)
  const afterDisc = base - disc
  const vatMult = 1 + Number(item.vat_percent) / 100
  const noVat = pricesIncludeVat ? afterDisc / vatMult : afterDisc
  const surcharge = item.item_type === 'Paleta' ? noVat * (Number(item.surcharge_percent) / 100) : 0
  return { noVat, surcharge, total: noVat + surcharge }
}

// ── Modal: pridanie / editácia položky ────────────────────────────────────────
function ItemModal({ item, products, onSave, onClose }) {
  const [form, setForm] = useState(item || {
    _key: genId(), item_type: 'Tovar', name: '', unit: 'ks',
    qty: 1, unit_price: 0, vat_percent: 20, discount_percent: 0, surcharge_percent: 0,
    product_unique_id: null, description: '',
  })
  const [prodSearch, setProdSearch] = useState('')
  const [showProdList, setShowProdList] = useState(false)
  const searchRef = useRef(null)

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }))

  const filteredProds = prodSearch.trim()
    ? products.filter((p) => p.name.toLowerCase().includes(prodSearch.toLowerCase()) || (p.plu || '').includes(prodSearch))
    : products.slice(0, 8)

  const selectProduct = (p) => {
    setForm((f) => ({ ...f, product_unique_id: p.unique_id, name: p.name, unit: p.unit || 'ks' }))
    setProdSearch(p.name)
    setShowProdList(false)
  }

  const clearProduct = () => {
    setForm((f) => ({ ...f, product_unique_id: null }))
    setProdSearch('')
  }

  const valid = form.name.trim().length > 0

  return (
    <div className="qf-modal-overlay" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="qf-modal">
        <div className="qf-modal-header">
          <h3>{item ? 'Upraviť položku' : 'Pridať položku'}</h3>
          <button type="button" className="qf-modal-close" onClick={onClose}>×</button>
        </div>
        <div className="qf-modal-body">
          <div className="qf-row">
            <label className="qf-label">Typ</label>
            <select className="qf-input" value={form.item_type} onChange={(e) => set('item_type', e.target.value)}>
              {ITEM_TYPES.map((t) => <option key={t}>{t}</option>)}
            </select>
          </div>

          <div className="qf-row">
            <label className="qf-label">Produkt (voliteľné)</label>
            {form.product_unique_id ? (
              <div className="qf-product-chip">
                <span>{form.name}</span>
                <button type="button" onClick={clearProduct}>×</button>
              </div>
            ) : (
              <div className="qf-autocomplete" ref={searchRef}>
                <input
                  type="text"
                  className="qf-input"
                  placeholder="Hľadať produkt…"
                  value={prodSearch}
                  onChange={(e) => { setProdSearch(e.target.value); setShowProdList(true) }}
                  onFocus={() => setShowProdList(true)}
                  onBlur={() => setTimeout(() => setShowProdList(false), 150)}
                />
                {showProdList && filteredProds.length > 0 && (
                  <ul className="qf-autocomplete-list">
                    {filteredProds.map((p) => (
                      <li key={`${p.unique_id}-${p.warehouse_id ?? ''}`}>
                        <button type="button" onMouseDown={() => selectProduct(p)}>
                          <span>{p.name}</span>
                          <span className="qf-prod-plu">PLU: {p.plu}</span>
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            )}
          </div>

          <div className="qf-row">
            <label className="qf-label">Názov *</label>
            <input className="qf-input" value={form.name} onChange={(e) => set('name', e.target.value)} placeholder="Názov položky" />
          </div>

          <div className="qf-row-2">
            <div>
              <label className="qf-label">Množstvo</label>
              <input type="number" className="qf-input" min="0" step="0.001" value={form.qty} onChange={(e) => set('qty', e.target.value)} />
            </div>
            <div>
              <label className="qf-label">Jednotka</label>
              <input className="qf-input" value={form.unit} onChange={(e) => set('unit', e.target.value)} placeholder="ks" />
            </div>
          </div>

          <div className="qf-row-2">
            <div>
              <label className="qf-label">Jedn. cena (bez DPH)</label>
              <input type="number" className="qf-input" min="0" step="0.01" value={form.unit_price} onChange={(e) => set('unit_price', e.target.value)} />
            </div>
            <div>
              <label className="qf-label">DPH %</label>
              <select className="qf-input" value={form.vat_percent} onChange={(e) => set('vat_percent', Number(e.target.value))}>
                {VAT_RATES.map((r) => <option key={r} value={r}>{r} %</option>)}
              </select>
            </div>
          </div>

          <div className="qf-row-2">
            <div>
              <label className="qf-label">Zľava %</label>
              <input type="number" className="qf-input" min="0" max="100" step="0.01" value={form.discount_percent} onChange={(e) => set('discount_percent', e.target.value)} />
            </div>
            <div>
              <label className="qf-label">{form.item_type === 'Paleta' ? 'Amortizácia %' : 'Príplatok %'}</label>
              <input type="number" className="qf-input" min="0" step="0.01" value={form.surcharge_percent} onChange={(e) => set('surcharge_percent', e.target.value)} />
            </div>
          </div>

          <div className="qf-row">
            <label className="qf-label">Popis</label>
            <textarea className="qf-input qf-textarea" value={form.description} onChange={(e) => set('description', e.target.value)} rows={2} />
          </div>
        </div>
        <div className="qf-modal-footer">
          <button type="button" className="btn-secondary" onClick={onClose}>Zrušiť</button>
          <button type="button" className="btn-primary" disabled={!valid} onClick={() => onSave(form)}>
            {item ? 'Uložiť' : 'Pridať'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Modal: vytvorenie produktu ─────────────────────────────────────────────────
function CreateProductModal({ auth, onCreated, onClose }) {
  const [form, setForm] = useState({ name: '', plu: '', ean: '', unit: 'ks' })
  const [saving, setSaving] = useState(false)
  const [err, setErr] = useState('')
  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }))

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!form.name.trim() || !form.plu.trim()) { setErr('Názov a PLU sú povinné'); return }
    setSaving(true); setErr('')
    try {
      const unique_id = `web_${Date.now()}_${Math.random().toString(36).slice(2)}`
      const res = await fetch(`${API_BASE_FOR_CALLS}/products`, {
        method: 'POST',
        headers: { ...getAuthHeaders(auth), 'Content-Type': 'application/json' },
        body: JSON.stringify({ unique_id, name: form.name.trim(), plu: form.plu.trim(), ean: form.ean.trim() || null, unit: form.unit || 'ks' }),
      })
      const data = await res.json()
      if (!res.ok) { setErr(data.error || 'Chyba'); setSaving(false); return }
      onCreated(data)
    } catch (_) { setErr('Chyba siete'); setSaving(false) }
  }

  return (
    <div className="qf-modal-overlay" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="qf-modal">
        <div className="qf-modal-header">
          <h3>Nový produkt</h3>
          <button type="button" className="qf-modal-close" onClick={onClose}>×</button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="qf-modal-body">
            {err && <p className="qf-error">{err}</p>}
            <div className="qf-row">
              <label className="qf-label">Názov *</label>
              <input className="qf-input" value={form.name} onChange={(e) => set('name', e.target.value)} autoFocus />
            </div>
            <div className="qf-row-2">
              <div>
                <label className="qf-label">PLU *</label>
                <input className="qf-input" value={form.plu} onChange={(e) => set('plu', e.target.value)} />
              </div>
              <div>
                <label className="qf-label">EAN</label>
                <input className="qf-input" value={form.ean} onChange={(e) => set('ean', e.target.value)} />
              </div>
            </div>
            <div className="qf-row">
              <label className="qf-label">Jednotka</label>
              <input className="qf-input" value={form.unit} onChange={(e) => set('unit', e.target.value)} placeholder="ks" />
            </div>
          </div>
          <div className="qf-modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>Zrušiť</button>
            <button type="submit" className="btn-primary" disabled={saving}>
              {saving ? <span className="btn-spinner" /> : 'Vytvoriť'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

// ── Hlavná stránka formulára ───────────────────────────────────────────────────
export default function QuoteFormPage() {
  const navigate = useNavigate()
  const { id } = useParams()
  const isNew = id === 'new'
  const [auth, setAuth] = useState(null)
  const [customers, setCustomers] = useState([])
  const [products, setProducts] = useState([])
  const [saving, setSaving] = useState(false)
  const [loadingData, setLoadingData] = useState(!isNew)
  const [itemModal, setItemModal] = useState(null) // null | 'new' | item-object
  const [showCreateProduct, setShowCreateProduct] = useState(false)
  const [custSearch, setCustSearch] = useState('')
  const [showCustList, setShowCustList] = useState(false)
  const [err, setErr] = useState('')

  const today = new Date().toISOString().slice(0, 10)
  const [form, setForm] = useState({
    quote_number: '',
    customer_id: null, customer_name: '', customer_ico: '', customer_address: '',
    issue_date: today,
    valid_until: new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10),
    status: 'draft',
    notes: '',
    delivery_cost: 0,
    other_fees: 0,
    prices_include_vat: false,
    items: [],
  })

  const setF = (k, v) => setForm((f) => ({ ...f, [k]: v }))

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  // Načíta zákazníkov a produkty
  useEffect(() => {
    if (!auth) return
    const h = getAuthHeaders(auth)
    Promise.all([
      fetch(`${API_BASE_FOR_CALLS}/customers`, { headers: h }).then((r) => r.ok ? r.json() : []),
      fetch(`${API_BASE_FOR_CALLS}/products`, { headers: h }).then((r) => r.ok ? r.json() : []),
    ]).then(([c, p]) => {
      setCustomers(Array.isArray(c) ? c : [])
      setProducts(Array.isArray(p) ? p : [])
    }).catch(() => {})
  }, [auth])

  // Načíta existujúcu ponuku pri editácii
  useEffect(() => {
    if (!auth || isNew) { setLoadingData(false); return }
    fetch(`${API_BASE_FOR_CALLS}/quotes/${id}`, { headers: getAuthHeaders(auth) })
      .then((r) => r.ok ? r.json() : Promise.reject())
      .then((q) => {
        setCustSearch(q.customer_name || '')
        setForm({
          quote_number: q.quote_number,
          customer_id: q.customer_id,
          customer_name: q.customer_name || '',
          customer_ico: q.customer_ico || '',
          customer_address: q.customer_address || '',
          issue_date: q.issue_date ? q.issue_date.slice(0, 10) : today,
          valid_until: q.valid_until ? q.valid_until.slice(0, 10) : '',
          status: q.status,
          notes: q.notes || '',
          delivery_cost: q.delivery_cost || 0,
          other_fees: q.other_fees || 0,
          prices_include_vat: !!q.prices_include_vat,
          items: (q.items || []).map((it) => ({ ...it, _key: genId() })),
        })
        setLoadingData(false)
      })
      .catch(() => { navigate('/dashboard/quotes', { replace: true }) })
  }, [auth, id, isNew, navigate, today])

  // Generovanie čísla ponuky pre nové
  useEffect(() => {
    if (!auth || !isNew) return
    const year = new Date().getFullYear()
    fetch(`${API_BASE_FOR_CALLS}/quotes?status=`, { headers: getAuthHeaders(auth) })
      .then((r) => r.ok ? r.json() : [])
      .then((all) => {
        const nums = all
          .map((q) => { const m = q.quote_number?.match(/(\d+)$/); return m ? parseInt(m[1], 10) : 0 })
          .filter(Boolean)
        const next = nums.length ? Math.max(...nums) + 1 : 1
        setF('quote_number', `CP-${year}-${String(next).padStart(4, '0')}`)
      })
      .catch(() => setF('quote_number', `CP-${year}-0001`))
  }, [auth, isNew])

  const filteredCustomers = custSearch.trim()
    ? customers.filter((c) => c.name.toLowerCase().includes(custSearch.toLowerCase()) || (c.ico || '').includes(custSearch))
    : customers.slice(0, 6)

  const selectCustomer = (c) => {
    setForm((f) => ({ ...f, customer_id: c.id, customer_name: c.name, customer_ico: c.ico || '', customer_address: [c.address, c.city].filter(Boolean).join(', ') }))
    setCustSearch(c.name)
    setShowCustList(false)
  }

  const clearCustomer = () => {
    setForm((f) => ({ ...f, customer_id: null, customer_name: '', customer_ico: '', customer_address: '' }))
    setCustSearch('')
  }

  // Výpočty súm
  const piv = form.prices_include_vat
  const goodsTotal = form.items.filter((i) => i.item_type !== 'Paleta').reduce((s, i) => s + calcItemTotal(i, piv).noVat, 0)
  const palletBase = form.items.filter((i) => i.item_type === 'Paleta').reduce((s, i) => s + calcItemTotal(i, piv).noVat, 0)
  const amortTotal = form.items.filter((i) => i.item_type === 'Paleta').reduce((s, i) => s + calcItemTotal(i, piv).surcharge, 0)
  const delivery = Number(form.delivery_cost) || 0
  const other = Number(form.other_fees) || 0
  const total = goodsTotal + amortTotal + delivery + other

  const saveQuote = async () => {
    if (!form.quote_number.trim()) { setErr('Číslo ponuky je povinné'); return }
    setSaving(true); setErr('')
    const body = {
      ...form,
      prices_include_vat: form.prices_include_vat ? 1 : 0,
      total_amount: Math.round(total * 100) / 100,
      items: form.items.map(({ _key, ...rest }) => rest),
    }
    try {
      const url = isNew ? `${API_BASE_FOR_CALLS}/quotes` : `${API_BASE_FOR_CALLS}/quotes/${id}`
      const res = await fetch(url, {
        method: isNew ? 'POST' : 'PUT',
        headers: { ...getAuthHeaders(auth), 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
      const data = await res.json()
      if (!res.ok) { setErr(data.error || 'Chyba uloženia'); setSaving(false); return }
      navigate(`/dashboard/quotes/${data.id}`)
    } catch (_) { setErr('Chyba siete'); setSaving(false) }
  }

  if (!auth || loadingData) return (
    <div className="dashboard-loading" style={{ padding: '3rem' }}>
      <span className="btn-spinner" /><span>Načítavam...</span>
    </div>
  )

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main qf-main">
        {/* Header */}
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard/quotes')}>← Späť</button>
          <h2 className="dashboard-overview-title">{isNew ? 'Nová cenová ponuka' : `Ponuka ${form.quote_number}`}</h2>
          <div style={{ marginLeft: 'auto', display: 'flex', gap: '0.5rem' }}>
            <button type="button" className="btn-secondary" onClick={() => navigate('/dashboard/quotes')}>Zrušiť</button>
            <button type="button" className="btn-primary" onClick={saveQuote} disabled={saving}>
              {saving ? <><span className="btn-spinner" /> Ukladám…</> : 'Uložiť ponuku'}
            </button>
          </div>
        </div>
        {err && <p className="qf-error">{err}</p>}

        <div className="qf-grid">
          {/* ── Základné info ── */}
          <section className="qf-card">
            <h3 className="qf-card-title">Základné informácie</h3>
            <div className="qf-row-2">
              <div>
                <label className="qf-label">Číslo ponuky *</label>
                <input className="qf-input" value={form.quote_number} onChange={(e) => setF('quote_number', e.target.value)} />
              </div>
              <div>
                <label className="qf-label">Stav</label>
                <select className="qf-input" value={form.status} onChange={(e) => setF('status', e.target.value)}>
                  <option value="draft">Návrh</option>
                  <option value="sent">Odoslaná</option>
                  <option value="accepted">Prijatá</option>
                  <option value="rejected">Zamietnutá</option>
                </select>
              </div>
            </div>
            <div className="qf-row-2">
              <div>
                <label className="qf-label">Dátum vystavenia</label>
                <input type="date" className="qf-input" value={form.issue_date} onChange={(e) => setF('issue_date', e.target.value)} />
              </div>
              <div>
                <label className="qf-label">Platná do</label>
                <input type="date" className="qf-input" value={form.valid_until} onChange={(e) => setF('valid_until', e.target.value)} />
              </div>
            </div>
          </section>

          {/* ── Zákazník ── */}
          <section className="qf-card">
            <h3 className="qf-card-title">Zákazník</h3>
            {form.customer_id ? (
              <div className="qf-product-chip" style={{ marginBottom: '0.75rem' }}>
                <span>{form.customer_name}</span>
                <button type="button" onClick={clearCustomer}>×</button>
              </div>
            ) : (
              <div className="qf-autocomplete" style={{ marginBottom: '0.75rem' }}>
                <input
                  type="text"
                  className="qf-input"
                  placeholder="Hľadať zákazníka…"
                  value={custSearch}
                  onChange={(e) => { setCustSearch(e.target.value); setShowCustList(true) }}
                  onFocus={() => setShowCustList(true)}
                  onBlur={() => setTimeout(() => setShowCustList(false), 150)}
                />
                {showCustList && filteredCustomers.length > 0 && (
                  <ul className="qf-autocomplete-list">
                    {filteredCustomers.map((c) => (
                      <li key={c.id}>
                        <button type="button" onMouseDown={() => selectCustomer(c)}>
                          <span>{c.name}</span>
                          <span className="qf-prod-plu">IČO: {c.ico}</span>
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            )}
            <div className="qf-row">
              <label className="qf-label">Názov zákazníka</label>
              <input className="qf-input" value={form.customer_name} onChange={(e) => setF('customer_name', e.target.value)} />
            </div>
            <div className="qf-row-2">
              <div>
                <label className="qf-label">IČO</label>
                <input className="qf-input" value={form.customer_ico} onChange={(e) => setF('customer_ico', e.target.value)} />
              </div>
              <div>
                <label className="qf-label">Adresa</label>
                <input className="qf-input" value={form.customer_address} onChange={(e) => setF('customer_address', e.target.value)} />
              </div>
            </div>
          </section>

          {/* ── Položky ── */}
          <section className="qf-card qf-card--full">
            <div className="qf-card-header">
              <h3 className="qf-card-title">Položky</h3>
              <div style={{ display: 'flex', gap: '0.5rem' }}>
                <button type="button" className="btn-secondary" onClick={() => setShowCreateProduct(true)}>
                  + Nový produkt
                </button>
                <button type="button" className="btn-primary" onClick={() => setItemModal('new')}>
                  + Pridať položku
                </button>
              </div>
            </div>

            <label className="qf-checkbox-row">
              <input type="checkbox" checked={form.prices_include_vat} onChange={(e) => setF('prices_include_vat', e.target.checked)} />
              <span>Ceny vrátane DPH</span>
            </label>

            {form.items.length === 0 ? (
              <p className="qf-items-empty">Žiadne položky. Kliknite „+ Pridať položku".</p>
            ) : (
              <div className="qf-items-table-wrap">
                <table className="qf-items-table">
                  <thead>
                    <tr>
                      <th>Názov</th><th>Typ</th><th>Mn.</th><th>Jedn. cena</th>
                      <th>Zľava</th><th>DPH</th><th>Spolu bez DPH</th><th />
                    </tr>
                  </thead>
                  <tbody>
                    {form.items.map((it) => {
                      const { noVat, surcharge } = calcItemTotal(it, piv)
                      return (
                        <tr key={it._key}>
                          <td>
                            <div className="qf-items-name">{it.name}</div>
                            {it.description && <div className="qf-items-desc">{it.description}</div>}
                          </td>
                          <td><span className={`qf-type-badge qf-type--${it.item_type.toLowerCase()}`}>{it.item_type}</span></td>
                          <td>{it.qty} {it.unit}</td>
                          <td>{formatEur(it.unit_price)}</td>
                          <td>{it.discount_percent > 0 ? `${it.discount_percent}%` : '—'}</td>
                          <td>{it.vat_percent}%</td>
                          <td>
                            {formatEur(noVat)}
                            {surcharge > 0 && <div className="qf-items-amort">+{formatEur(surcharge)} amort.</div>}
                          </td>
                          <td className="qf-items-actions">
                            <button type="button" title="Upraviť" onClick={() => setItemModal(it)}>✏️</button>
                            <button type="button" title="Zmazať" onClick={() => setF('items', form.items.filter((i) => i._key !== it._key))}>🗑️</button>
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </section>

          {/* ── Poplatky + Súhrn ── */}
          <section className="qf-card">
            <h3 className="qf-card-title">Poplatky</h3>
            <div className="qf-row-2">
              <div>
                <label className="qf-label">Doprava (€)</label>
                <input type="number" className="qf-input" min="0" step="0.01" value={form.delivery_cost} onChange={(e) => setF('delivery_cost', e.target.value)} />
              </div>
              <div>
                <label className="qf-label">Ostatné poplatky (€)</label>
                <input type="number" className="qf-input" min="0" step="0.01" value={form.other_fees} onChange={(e) => setF('other_fees', e.target.value)} />
              </div>
            </div>
            <div className="qf-row">
              <label className="qf-label">Poznámky</label>
              <textarea className="qf-input qf-textarea" rows={3} value={form.notes} onChange={(e) => setF('notes', e.target.value)} placeholder="Podmienky, poznámky k ponuke…" />
            </div>
          </section>

          <section className="qf-card qf-summary">
            <h3 className="qf-card-title">Súhrn</h3>
            <div className="qf-summary-row"><span>Cena tovaru bez DPH</span><span>{formatEur(goodsTotal)}</span></div>
            {amortTotal > 0 && <div className="qf-summary-row"><span>Amortizácia paliet</span><span>{formatEur(amortTotal)}</span></div>}
            {delivery > 0 && <div className="qf-summary-row"><span>Doprava</span><span>{formatEur(delivery)}</span></div>}
            {other > 0 && <div className="qf-summary-row"><span>Ostatné poplatky</span><span>{formatEur(other)}</span></div>}
            {palletBase > 0 && <div className="qf-summary-row qf-summary-row--muted"><span>Vratná záloha za palety</span><span>{formatEur(palletBase)}</span></div>}
            <div className="qf-summary-row qf-summary-total"><span>Celková cena na úhradu</span><span>{formatEur(total)}</span></div>
          </section>
        </div>
      </main>

      {/* Modals */}
      {itemModal && (
        <ItemModal
          item={itemModal === 'new' ? null : itemModal}
          products={products}
          onSave={(saved) => {
            if (itemModal === 'new') {
              setF('items', [...form.items, { ...saved, _key: saved._key || genId() }])
            } else {
              setF('items', form.items.map((i) => i._key === saved._key ? saved : i))
            }
            setItemModal(null)
          }}
          onClose={() => setItemModal(null)}
        />
      )}

      {showCreateProduct && (
        <CreateProductModal
          auth={auth}
          onCreated={(p) => { setProducts((prev) => [...prev, p]); setShowCreateProduct(false) }}
          onClose={() => setShowCreateProduct(false)}
        />
      )}
    </div>
  )
}
