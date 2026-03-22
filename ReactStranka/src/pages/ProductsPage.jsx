import { useState, useEffect, useCallback } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import './DashboardPage.css'
import '../components/DetailDrawer.css'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'
import { validateEanChecksum } from '../utils/eanValidation'
import DetailDrawer, { DrawerRow } from '../components/DetailDrawer'
import ProductsFiltersBar from '../components/products/ProductsFiltersBar'
import ProductPricingRulesList from '../components/products/ProductPricingRulesList'

const EMPTY_FORM = { name: '', plu: '', ean: '', unit: 'ks' }

/** Max. počet produktov na stránku (zhodné s limitom na API). */
const PRODUCTS_PAGE_SIZE = 100

function stockBadge(qty) {
  if (qty == null) return null
  if (qty === 0) return { cls: 'item-card-badge--stock-zero', label: '0 ks' }
  if (qty < 5) return { cls: 'item-card-badge--stock-low', label: `${qty}` }
  return { cls: 'item-card-badge--stock', label: `${qty}` }
}

function parseApiSaveError(data) {
  if (!data || typeof data !== 'object') return 'Uloženie zlyhalo'
  if (data.message) return data.message
  const err = data.error
  if (err === 'DUPLICATE_PLU') return data.message || 'Iný produkt už má toto PLU.'
  if (err === 'DUPLICATE_EAN') return data.message || 'Iný produkt už má tento EAN.'
  if (typeof err === 'string' && err.length > 0 && err.length < 200) return err
  return 'Uloženie zlyhalo'
}

/** Porovná query bez ohľadu na poradie kľúčov (predchádza zbytočným setSearchParams). */
function urlSearchParamsEqual(a, b) {
  const sorted = (usp) => [...usp.entries()].sort(([x], [y]) => x.localeCompare(y))
  const ea = sorted(a)
  const eb = sorted(b)
  if (ea.length !== eb.length) return false
  return ea.every(([k, v], i) => k === eb[i][0] && v === eb[i][1])
}

export default function ProductsPage() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const [auth, setAuth] = useState(null)
  const [warehouses, setWarehouses] = useState([])
  const [products, setProducts] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState(() => searchParams.get('search') || '')
  const [warehouseId, setWarehouseId] = useState(() => searchParams.get('warehouse_id') || '')
  const [stockFilter, setStockFilter] = useState(() => {
    if (searchParams.get('stock_out') === '1') return 'out'
    if (searchParams.get('low_stock') === '1') return 'low'
    return 'all'
  })
  const [sort, setSort] = useState(() => searchParams.get('sort') || 'name_asc')
  const [page, setPage] = useState(() => Math.max(1, parseInt(searchParams.get('page') || '1', 10) || 1))
  const [total, setTotal] = useState(0)

  const [selected, setSelected] = useState(null)
  const [mode, setMode] = useState('view')
  const [form, setForm] = useState(EMPTY_FORM)
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState('')

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  useEffect(() => {
    if (!auth) return
    fetch(`${API_BASE_FOR_CALLS}/warehouses`, { headers: getAuthHeaders(auth) })
      .then((r) => (r.ok ? r.json() : []))
      .then((rows) => setWarehouses(Array.isArray(rows) ? rows : []))
      .catch(() => setWarehouses([]))
  }, [auth])

  useEffect(() => {
    if (!auth) return
    const next = new URLSearchParams()
    if (search.trim()) next.set('search', search.trim())
    if (warehouseId) next.set('warehouse_id', warehouseId)
    if (stockFilter === 'low') next.set('low_stock', '1')
    else if (stockFilter === 'out') next.set('stock_out', '1')
    if (sort !== 'name_asc') next.set('sort', sort)
    if (page > 1) next.set('page', String(page))
    if (!urlSearchParamsEqual(next, searchParams)) setSearchParams(next, { replace: true })
  }, [auth, search, warehouseId, stockFilter, sort, page, setSearchParams, searchParams])

  const fetchProducts = useCallback(async () => {
    if (!auth) return
    setLoading(true)
    setError('')
    try {
      const params = new URLSearchParams()
      params.set('page', String(page))
      params.set('limit', String(PRODUCTS_PAGE_SIZE))
      if (search.trim()) params.set('search', search.trim())
      if (warehouseId) params.set('warehouse_id', warehouseId)
      if (stockFilter === 'low') params.set('low_stock', '1')
      if (stockFilter === 'out') params.set('stock_out', '1')
      params.set('sort', sort || 'name_asc')
      const res = await fetch(`${API_BASE_FOR_CALLS}/products?${params}`, { headers: getAuthHeaders(auth) })
      if (!res.ok) throw new Error('Načítanie zlyhalo')
      const data = await res.json()
      if (data && Array.isArray(data.items)) {
        setProducts(data.items)
        setTotal(typeof data.total === 'number' ? data.total : data.items.length)
      } else if (Array.isArray(data)) {
        setProducts(data)
        setTotal(data.length)
      } else {
        setProducts([])
        setTotal(0)
      }
    } catch (e) {
      setError(e.message || 'Chyba')
    } finally {
      setLoading(false)
    }
  }, [auth, search, page, warehouseId, stockFilter, sort])

  useEffect(() => {
    if (!auth) return
    const t = setTimeout(() => { fetchProducts() }, 250)
    return () => clearTimeout(t)
  }, [auth, search, page, warehouseId, stockFilter, sort, fetchProducts])

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

  const goToDetailPage = (uniqueId) => {
    navigate(`/dashboard/products/${encodeURIComponent(uniqueId)}`)
  }

  const handleSave = async () => {
    if (!form.name.trim() || !form.plu.trim()) {
      setSaveError('Názov a PLU sú povinné')
      return
    }
    const eanCheck = validateEanChecksum(form.ean)
    if (!eanCheck.ok) {
      setSaveError(eanCheck.message || 'Neplatný EAN')
      return
    }
    setSaving(true)
    setSaveError('')
    try {
      let res
      let data
      if (mode === 'create') {
        const unique_id = crypto.randomUUID()
        res = await fetch(`${API_BASE_FOR_CALLS}/products`, {
          method: 'POST',
          headers: getAuthHeaders(auth),
          body: JSON.stringify({
            unique_id,
            name: form.name.trim(),
            plu: form.plu.trim(),
            ean: form.ean.trim() || null,
            unit: form.unit || 'ks',
            qty: 0,
          }),
        })
      } else {
        res = await fetch(`${API_BASE_FOR_CALLS}/products/${encodeURIComponent(selected.unique_id)}`, {
          method: 'PUT',
          headers: getAuthHeaders(auth),
          body: JSON.stringify({
            name: form.name.trim(),
            plu: form.plu.trim(),
            ean: form.ean.trim() || null,
            unit: form.unit || 'ks',
          }),
        })
      }
      data = await res.json().catch(() => ({}))
      if (!res.ok) {
        setSaveError(parseApiSaveError(data))
        return
      }

      await fetchProducts()
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

  const totalPages = total <= 0 ? 1 : Math.ceil(total / PRODUCTS_PAGE_SIZE)
  const rangeFrom = total === 0 ? 0 : (page - 1) * PRODUCTS_PAGE_SIZE + 1
  const rangeTo = Math.min(page * PRODUCTS_PAGE_SIZE, total)

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
              onChange={(e) => {
                setSearch(e.target.value)
                setPage(1)
              }}
              aria-label="Hľadať produkty"
            />
            <button type="button" className="items-create-btn" onClick={openCreate}>
              + Nový produkt
            </button>
          </div>

          <ProductsFiltersBar
            warehouses={warehouses}
            warehouseId={warehouseId}
            onWarehouseChange={(v) => { setWarehouseId(v); setPage(1) }}
            stockFilter={stockFilter}
            onStockFilterChange={(v) => { setStockFilter(v); setPage(1) }}
            sort={sort}
            onSortChange={(v) => { setSort(v); setPage(1) }}
          />

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
            <>
              <div className="items-grid">
                {products.map((p) => {
                  const badge = stockBadge(p.qty)
                  const rowKey = `${p.unique_id}::${p.warehouse_id ?? ''}`
                  return (
                    <div key={rowKey} className="item-card-wrap">
                      <button type="button" className="item-card" onClick={() => openItem(p)}>
                        <div className="item-card-top">
                          <span className="item-card-name">{p.name}</span>
                          {badge && (
                            <span className={`item-card-badge ${badge.cls}`}>
                              {badge.label} {p.unit || 'ks'}
                            </span>
                          )}
                        </div>
                        <div className="item-card-meta">
                          {p.warehouse_id != null && (
                            <span className="item-card-tag">Sklad #{p.warehouse_id}</span>
                          )}
                          {p.plu && <span className="item-card-tag">PLU {p.plu}</span>}
                          {p.ean && <span className="item-card-tag">EAN {p.ean}</span>}
                          {p.unit && p.unit !== 'ks' && <span className="item-card-tag">{p.unit}</span>}
                        </div>
                      </button>
                      <button
                        type="button"
                        className="item-card-detail-link"
                        title="Otvoriť detail na vlastnej stránke (zdieľateľný odkaz)"
                        aria-label={`Detail produktu ${p.name}`}
                        onClick={() => goToDetailPage(p.unique_id)}
                      >
                        Detail
                      </button>
                    </div>
                  )
                })}
              </div>
              {total > PRODUCTS_PAGE_SIZE || page > 1 ? (
                <nav className="items-pagination" aria-label="Stránkovanie produktov">
                  <span className="items-pagination-info" aria-live="polite">
                    {total > 0 ? `${rangeFrom}–${rangeTo} z ${total}` : '0'}
                  </span>
                  <div className="items-pagination-actions">
                    <button
                      type="button"
                      className="items-pagination-btn"
                      disabled={page <= 1 || loading}
                      onClick={() => setPage((x) => Math.max(1, x - 1))}
                      aria-label="Predchádzajúca strana"
                    >
                      Predchádzajúca
                    </button>
                    <span className="items-pagination-page" aria-current="page">
                      Strana {page} / {totalPages}
                    </span>
                    <button
                      type="button"
                      className="items-pagination-btn"
                      disabled={page >= totalPages || loading}
                      onClick={() => setPage((x) => x + 1)}
                      aria-label="Ďalšia strana"
                    >
                      Ďalšia
                    </button>
                  </div>
                </nav>
              ) : null}
            </>
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
          <>
            <dl className="drawer-dl">
              <DrawerRow label="Názov" value={selected.name} />
              <DrawerRow label="PLU" value={selected.plu} />
              <DrawerRow label="EAN" value={selected.ean} />
              <DrawerRow label="Jednotka" value={selected.unit || 'ks'} />
              <DrawerRow label="Na sklade" value={selected.qty != null ? `${selected.qty} ${selected.unit || 'ks'}` : '—'} />
              <DrawerRow label="ID" value={selected.unique_id} />
            </dl>
            <ProductPricingRulesList auth={auth} productUniqueId={selected.unique_id} />
            <button
              type="button"
              className="drawer-link-detail"
              onClick={() => goToDetailPage(selected.unique_id)}
            >
              Otvoriť stránku detailu (odkaz)
            </button>
            <p className="drawer-footnote">
              Mazanie a archivácia produktov je v mobilnej aplikácii Stock Pilot; na webe ich len upravujete a vytvárate.
            </p>
          </>
        ) : (mode === 'edit' || mode === 'create') ? (
          <div className="drawer-form">
            {saveError && <p className="drawer-save-error">{saveError}</p>}
            <div className="drawer-field">
              <label htmlFor="product-name-input">Názov *</label>
              <input
                id="product-name-input"
                type="text"
                value={form.name}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                placeholder="Názov produktu"
                autoFocus
              />
            </div>
            <div className="drawer-field-row">
              <div className="drawer-field">
                <label htmlFor="product-plu-input">PLU *</label>
                <input
                  id="product-plu-input"
                  type="text"
                  value={form.plu}
                  onChange={(e) => setForm((f) => ({ ...f, plu: e.target.value }))}
                  placeholder="napr. 1001"
                />
              </div>
              <div className="drawer-field">
                <label htmlFor="product-unit-input">Jednotka</label>
                <select id="product-unit-input" value={form.unit} onChange={(e) => setForm((f) => ({ ...f, unit: e.target.value }))}>
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
              <label htmlFor="product-ean-input">EAN / Čiarový kód</label>
              <input
                id="product-ean-input"
                type="text"
                inputMode="numeric"
                autoComplete="off"
                value={form.ean}
                onChange={(e) => setForm((f) => ({ ...f, ean: e.target.value }))}
                placeholder="nepovinné (8 alebo 13 číslic)"
              />
            </div>
          </div>
        ) : null}
      </DetailDrawer>
    </>
  )
}
