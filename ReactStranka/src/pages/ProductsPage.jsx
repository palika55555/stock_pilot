import { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import '../components/DetailDrawer.css'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'
import DetailDrawer, { DrawerRow } from '../components/DetailDrawer'

const EMPTY_FORM = { name: '', plu: '', ean: '', unit: 'ks' }

function stockBadge(qty) {
  if (qty == null) return null
  if (qty === 0) return { cls: 'item-card-badge--stock-zero', label: '0 ks' }
  if (qty < 5) return { cls: 'item-card-badge--stock-low', label: `${qty}` }
  return { cls: 'item-card-badge--stock', label: `${qty}` }
}

export default function ProductsPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [products, setProducts] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')

  // Drawer state
  const [selected, setSelected] = useState(null)
  const [mode, setMode] = useState('view') // 'view' | 'edit' | 'create'
  const [form, setForm] = useState(EMPTY_FORM)
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState('')

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  const fetchProducts = useCallback(async (a, q) => {
    if (!a) return
    setLoading(true)
    setError('')
    try {
      const url = q.trim()
        ? `${API_BASE_FOR_CALLS}/products?search=${encodeURIComponent(q)}`
        : `${API_BASE_FOR_CALLS}/products`
      const res = await fetch(url, { headers: getAuthHeaders(a) })
      if (!res.ok) throw new Error('Načítanie zlyhalo')
      const data = await res.json()
      setProducts(Array.isArray(data) ? data : [])
    } catch (e) {
      setError(e.message || 'Chyba')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    if (!auth) return
    const t = setTimeout(() => fetchProducts(auth, search), 250)
    return () => clearTimeout(t)
  }, [auth, search, fetchProducts])

  const openItem = (p) => {
    setSelected(p)
    setMode('view')
    setForm({ name: p.name, plu: p.plu, ean: p.ean || '', unit: p.unit || 'ks' })
    setSaveError('')
  }

  const openCreate = () => {
    setSelected(null)
    setMode('create')
    setForm(EMPTY_FORM)
    setSaveError('')
  }

  const closeDrawer = () => {
    setSelected(null)
    setMode('view')
    setSaveError('')
  }

  const handleSave = async () => {
    if (!form.name.trim() || !form.plu.trim()) {
      setSaveError('Názov a PLU sú povinné')
      return
    }
    setSaving(true)
    setSaveError('')
    try {
      let res, data
      if (mode === 'create') {
        const unique_id = crypto.randomUUID()
        res = await fetch(`${API_BASE_FOR_CALLS}/products`, {
          method: 'POST',
          headers: getAuthHeaders(auth),
          body: JSON.stringify({ unique_id, name: form.name.trim(), plu: form.plu.trim(), ean: form.ean.trim() || null, unit: form.unit || 'ks', qty: 0 }),
        })
      } else {
        res = await fetch(`${API_BASE_FOR_CALLS}/products/${encodeURIComponent(selected.unique_id)}`, {
          method: 'PUT',
          headers: getAuthHeaders(auth),
          body: JSON.stringify({ name: form.name.trim(), plu: form.plu.trim(), ean: form.ean.trim() || null, unit: form.unit || 'ks' }),
        })
      }
      data = await res.json().catch(() => ({}))
      if (!res.ok) { setSaveError(data.error || 'Uloženie zlyhalo'); return }

      await fetchProducts(auth, search)
      if (mode === 'create') {
        closeDrawer()
      } else {
        setSelected(data)
        setMode('view')
      }
    } catch (e) {
      setSaveError(e.message || 'Chyba')
    } finally {
      setSaving(false)
    }
  }

  const drawerOpen = selected !== null || mode === 'create'
  const drawerTitle = mode === 'create' ? 'Nový produkt' : (selected?.name ?? '')

  if (!auth) return null

  return (
    <>
      <div className="dashboard-page-content">
        <main className="dashboard-main" style={{ maxWidth: 1100 }}>
          <div className="dashboard-content-header" style={{ marginBottom: '1.25rem' }}>
            <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
            <h2 className="dashboard-overview-title">Produkty</h2>
          </div>

          <div className="items-toolbar">
            <input
              type="search"
              className="items-search"
              placeholder="Hľadať podľa názvu, PLU alebo EAN…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <button type="button" className="items-create-btn" onClick={openCreate}>
              + Nový produkt
            </button>
          </div>

          {loading ? (
            <div className="dashboard-loading">
              <span className="btn-spinner" aria-hidden="true" />
              <span>Načítavam produkty…</span>
            </div>
          ) : error ? (
            <p className="customers-error">{error}</p>
          ) : products.length === 0 ? (
            <p className="customers-empty">Žiadne produkty. Synchronizujte z aplikácie alebo vytvorte nový.</p>
          ) : (
            <div className="items-grid">
              {products.map((p) => {
                const badge = stockBadge(p.qty)
                return (
                  <button key={p.unique_id} type="button" className="item-card" onClick={() => openItem(p)}>
                    <div className="item-card-top">
                      <span className="item-card-name">{p.name}</span>
                      {badge && (
                        <span className={`item-card-badge ${badge.cls}`}>
                          {badge.label} {p.unit || 'ks'}
                        </span>
                      )}
                    </div>
                    <div className="item-card-meta">
                      {p.plu && <span className="item-card-tag">PLU {p.plu}</span>}
                      {p.ean && <span className="item-card-tag">EAN {p.ean}</span>}
                      {p.unit && p.unit !== 'ks' && <span className="item-card-tag">{p.unit}</span>}
                    </div>
                  </button>
                )
              })}
            </div>
          )}
        </main>
      </div>

      <DetailDrawer
        open={drawerOpen}
        onClose={closeDrawer}
        title={drawerTitle}
        mode={mode}
        onEdit={() => { setMode('edit'); setSaveError('') }}
        onSave={handleSave}
        onCancel={() => mode === 'create' ? closeDrawer() : (setMode('view'), setSaveError(''))}
        saving={saving}
      >
        {(mode === 'view' && selected) ? (
          <dl className="drawer-dl">
            <DrawerRow label="Názov" value={selected.name} />
            <DrawerRow label="PLU" value={selected.plu} />
            <DrawerRow label="EAN" value={selected.ean} />
            <DrawerRow label="Jednotka" value={selected.unit || 'ks'} />
            <DrawerRow label="Na sklade" value={selected.qty != null ? `${selected.qty} ${selected.unit || 'ks'}` : '—'} />
            <DrawerRow label="ID" value={selected.unique_id} />
          </dl>
        ) : (mode === 'edit' || mode === 'create') ? (
          <div className="drawer-form">
            {saveError && <p className="drawer-save-error">{saveError}</p>}
            <div className="drawer-field">
              <label>Názov *</label>
              <input
                type="text"
                value={form.name}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                placeholder="Názov produktu"
                autoFocus
              />
            </div>
            <div className="drawer-field-row">
              <div className="drawer-field">
                <label>PLU *</label>
                <input
                  type="text"
                  value={form.plu}
                  onChange={(e) => setForm((f) => ({ ...f, plu: e.target.value }))}
                  placeholder="napr. 1001"
                />
              </div>
              <div className="drawer-field">
                <label>Jednotka</label>
                <select value={form.unit} onChange={(e) => setForm((f) => ({ ...f, unit: e.target.value }))}>
                  <option value="ks">ks</option>
                  <option value="kg">kg</option>
                  <option value="l">l</option>
                  <option value="m">m</option>
                  <option value="m2">m²</option>
                  <option value="bal">bal</option>
                </select>
              </div>
            </div>
            <div className="drawer-field">
              <label>EAN / Čiarový kód</label>
              <input
                type="text"
                value={form.ean}
                onChange={(e) => setForm((f) => ({ ...f, ean: e.target.value }))}
                placeholder="nepovinné"
              />
            </div>
          </div>
        ) : null}
      </DetailDrawer>
    </>
  )
}
