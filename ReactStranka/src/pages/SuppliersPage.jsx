import { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import '../components/DetailDrawer.css'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'
import DetailDrawer, { DrawerRow } from '../components/DetailDrawer'

const EMPTY_FORM = {
  name: '', ico: '', email: '', address: '', city: '',
  postal_code: '', dic: '', ic_dph: '', default_vat_rate: 20, is_active: true,
}

function formFromSupplier(s) {
  return {
    name: s.name ?? '',
    ico: s.ico ?? '',
    email: s.email ?? '',
    address: s.address ?? '',
    city: s.city ?? '',
    postal_code: s.postal_code ?? '',
    dic: s.dic ?? '',
    ic_dph: s.ic_dph ?? '',
    default_vat_rate: s.default_vat_rate ?? 20,
    is_active: s.is_active !== false && s.is_active !== 0,
  }
}

export default function SuppliersPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [suppliers, setSuppliers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')

  // Drawer state
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

  const fetchSuppliers = useCallback(async (a) => {
    if (!a) return
    setLoading(true)
    setError('')
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/suppliers`, { headers: getAuthHeaders(a) })
      if (!res.ok) throw new Error('Načítanie zlyhalo')
      const data = await res.json()
      setSuppliers(Array.isArray(data) ? data : [])
    } catch (e) {
      setError(e.message || 'Chyba')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { if (auth) fetchSuppliers(auth) }, [auth, fetchSuppliers])

  const filtered = search.trim()
    ? suppliers.filter((s) => {
        const q = search.toLowerCase()
        return (
          s.name?.toLowerCase().includes(q) ||
          s.ico?.toLowerCase().includes(q) ||
          s.city?.toLowerCase().includes(q) ||
          s.email?.toLowerCase().includes(q)
        )
      })
    : suppliers

  const openItem = (s) => {
    setSelected(s)
    setMode('view')
    setForm(formFromSupplier(s))
    setSaveError('')
  }

  const openCreate = () => {
    setSelected(null)
    setMode('create')
    setForm(EMPTY_FORM)
    setSaveError('')
  }

  const closeDrawer = () => { setSelected(null); setMode('view'); setSaveError('') }

  const handleSave = async () => {
    if (!form.name.trim()) { setSaveError('Meno je povinné'); return }
    setSaving(true)
    setSaveError('')
    try {
      const body = {
        name: form.name.trim(),
        ico: form.ico.trim() || null,
        email: form.email.trim() || null,
        address: form.address.trim() || null,
        city: form.city.trim() || null,
        postal_code: form.postal_code.trim() || null,
        dic: form.dic.trim() || null,
        ic_dph: form.ic_dph.trim() || null,
        default_vat_rate: parseInt(form.default_vat_rate, 10) || 20,
        is_active: form.is_active,
      }
      const url = mode === 'create'
        ? `${API_BASE_FOR_CALLS}/suppliers`
        : `${API_BASE_FOR_CALLS}/suppliers/${selected.id}`
      const res = await fetch(url, {
        method: mode === 'create' ? 'POST' : 'PUT',
        headers: getAuthHeaders(auth),
        body: JSON.stringify(body),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) { setSaveError(data.error || 'Uloženie zlyhalo'); return }

      await fetchSuppliers(auth)
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
  const drawerTitle = mode === 'create' ? 'Nový dodávateľ' : (selected?.name ?? '')

  if (!auth) return null

  return (
    <>
      <div className="dashboard-page-content">
        <main className="dashboard-main" style={{ maxWidth: 1100 }}>
          <div className="dashboard-content-header" style={{ marginBottom: '1.25rem' }}>
            <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
            <h2 className="dashboard-overview-title">Dodávatelia</h2>
          </div>

          <div className="items-toolbar">
            <input
              type="search"
              className="items-search"
              placeholder="Hľadať podľa mena, IČO, mesta…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <button type="button" className="items-create-btn" onClick={openCreate}>
              + Nový dodávateľ
            </button>
          </div>

          {loading ? (
            <div className="dashboard-loading">
              <span className="btn-spinner" aria-hidden="true" />
              <span>Načítavam dodávateľov…</span>
            </div>
          ) : error ? (
            <p className="customers-error">{error}</p>
          ) : filtered.length === 0 ? (
            <p className="customers-empty">
              {search ? 'Žiadny dodávateľ nevyhovuje hľadaniu.' : 'Zatiaľ nemáte žiadnych dodávateľov.'}
            </p>
          ) : (
            <div className="items-grid">
              {filtered.map((s) => (
                <button key={s.id} type="button" className="item-card" onClick={() => openItem(s)}>
                  <div className="item-card-top">
                    <span className="item-card-name">{s.name}</span>
                    <span className={`item-card-badge ${s.is_active !== false && s.is_active !== 0 ? 'item-card-badge--active' : 'item-card-badge--inactive'}`}>
                      {s.is_active !== false && s.is_active !== 0 ? 'Aktívny' : 'Neaktívny'}
                    </span>
                  </div>
                  <div className="item-card-meta">
                    {s.ico && <span className="item-card-tag">IČO {s.ico}</span>}
                    {s.city && <span className="item-card-tag">{s.city}</span>}
                    {s.dic && <span className="item-card-tag">DIČ {s.dic}</span>}
                  </div>
                  {s.email && <span className="item-card-sub">{s.email}</span>}
                </button>
              ))}
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
        {mode === 'view' && selected ? (
          <dl className="drawer-dl">
            <DrawerRow label="IČO" value={selected.ico} />
            <DrawerRow label="DIČ" value={selected.dic} />
            <DrawerRow label="IČ DPH" value={selected.ic_dph} />
            <DrawerRow label="Email" value={selected.email} />
            <DrawerRow label="Adresa" value={selected.address} />
            <DrawerRow label="Mesto" value={selected.city} />
            <DrawerRow label="PSČ" value={selected.postal_code} />
            <DrawerRow label="DPH %" value={selected.default_vat_rate != null ? `${selected.default_vat_rate} %` : null} />
            <DrawerRow label="Stav">
              <span className={`drawer-badge ${selected.is_active !== false && selected.is_active !== 0 ? 'drawer-badge--active' : 'drawer-badge--inactive'}`}>
                {selected.is_active !== false && selected.is_active !== 0 ? 'Aktívny' : 'Neaktívny'}
              </span>
            </DrawerRow>
          </dl>
        ) : (mode === 'edit' || mode === 'create') ? (
          <div className="drawer-form">
            {saveError && <p className="drawer-save-error">{saveError}</p>}
            <div className="drawer-field">
              <label>Meno / Názov *</label>
              <input type="text" value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} placeholder="Meno dodávateľa" autoFocus />
            </div>
            <p className="drawer-section-title">Daňové údaje</p>
            <div className="drawer-field-row">
              <div className="drawer-field">
                <label>IČO</label>
                <input type="text" value={form.ico} onChange={(e) => setForm((f) => ({ ...f, ico: e.target.value }))} placeholder="12345678" />
              </div>
              <div className="drawer-field">
                <label>DIČ</label>
                <input type="text" value={form.dic} onChange={(e) => setForm((f) => ({ ...f, dic: e.target.value }))} />
              </div>
            </div>
            <div className="drawer-field-row">
              <div className="drawer-field">
                <label>IČ DPH</label>
                <input type="text" value={form.ic_dph} onChange={(e) => setForm((f) => ({ ...f, ic_dph: e.target.value }))} placeholder="SK..." />
              </div>
              <div className="drawer-field">
                <label>Predvolená DPH %</label>
                <input type="number" min="0" max="100" value={form.default_vat_rate} onChange={(e) => setForm((f) => ({ ...f, default_vat_rate: e.target.value }))} />
              </div>
            </div>
            <p className="drawer-section-title">Kontakt &amp; Adresa</p>
            <div className="drawer-field">
              <label>Email</label>
              <input type="email" value={form.email} onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))} placeholder="email@example.com" />
            </div>
            <div className="drawer-field">
              <label>Adresa</label>
              <input type="text" value={form.address} onChange={(e) => setForm((f) => ({ ...f, address: e.target.value }))} placeholder="Ulica a číslo" />
            </div>
            <div className="drawer-field-row">
              <div className="drawer-field">
                <label>Mesto</label>
                <input type="text" value={form.city} onChange={(e) => setForm((f) => ({ ...f, city: e.target.value }))} />
              </div>
              <div className="drawer-field">
                <label>PSČ</label>
                <input type="text" value={form.postal_code} onChange={(e) => setForm((f) => ({ ...f, postal_code: e.target.value }))} placeholder="831 01" />
              </div>
            </div>
            <label className="drawer-checkbox-row">
              <input type="checkbox" checked={form.is_active} onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))} />
              <span>Aktívny dodávateľ</span>
            </label>
          </div>
        ) : null}
      </DetailDrawer>
    </>
  )
}
