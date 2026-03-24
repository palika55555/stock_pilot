import { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import '../components/DetailDrawer.css'
import { getAuth } from '../utils/auth'
import { apiFetch } from '../utils/apiFetch'
import DetailDrawer, { DrawerRow } from '../components/DetailDrawer'

const EMPTY_FORM = {
  name: '', ico: '', email: '', address: '', city: '',
  postal_code: '', dic: '', ic_dph: '', default_vat_rate: 20, is_active: true,
}

function formFromCustomer(c) {
  return {
    name: c.name ?? '',
    ico: c.ico ?? '',
    email: c.email ?? '',
    address: c.address ?? '',
    city: c.city ?? '',
    postal_code: c.postal_code ?? '',
    dic: c.dic ?? '',
    ic_dph: c.ic_dph ?? '',
    default_vat_rate: c.default_vat_rate ?? 20,
    is_active: c.is_active !== 0,
  }
}

export default function CustomersPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [customers, setCustomers] = useState([])
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

  const fetchCustomers = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const data = await apiFetch('/customers')
      setCustomers(Array.isArray(data) ? data : [])
    } catch (e) {
      setError(e.message || 'Chyba')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { if (auth) fetchCustomers() }, [auth, fetchCustomers])

  const filtered = search.trim()
    ? customers.filter((c) => {
        const q = search.toLowerCase()
        return (
          c.name?.toLowerCase().includes(q) ||
          c.ico?.toLowerCase().includes(q) ||
          c.city?.toLowerCase().includes(q) ||
          c.email?.toLowerCase().includes(q)
        )
      })
    : customers

  const openItem = (c) => {
    setSelected(c)
    setMode('view')
    setForm(formFromCustomer(c))
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
    if (!form.name.trim() || !form.ico.trim()) {
      setSaveError('Meno a IČO sú povinné')
      return
    }
    setSaving(true)
    setSaveError('')
    try {
      const body = {
        name: form.name.trim(),
        ico: form.ico.trim(),
        email: form.email.trim() || null,
        address: form.address.trim() || null,
        city: form.city.trim() || null,
        postal_code: form.postal_code.trim() || null,
        dic: form.dic.trim() || null,
        ic_dph: form.ic_dph.trim() || null,
        default_vat_rate: parseInt(form.default_vat_rate, 10) || 20,
        is_active: form.is_active,
      }
      const data = await apiFetch(
        mode === 'create' ? '/customers' : `/customers/${selected.id}`,
        { method: mode === 'create' ? 'POST' : 'PUT', body: JSON.stringify(body) },
      )

      await fetchCustomers()
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
  const drawerTitle = mode === 'create' ? 'Nový zákazník' : (selected?.name ?? '')

  if (!auth) return null

  return (
    <>
      <div className="dashboard-page-content">
        <main className="dashboard-main" style={{ maxWidth: 1100 }}>
          <div className="dashboard-content-header" style={{ marginBottom: '1.25rem' }}>
            <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
            <h2 className="dashboard-overview-title">Zákazníci</h2>
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
              + Nový zákazník
            </button>
          </div>

          {loading ? (
            <div className="dashboard-loading">
              <span className="btn-spinner" aria-hidden="true" />
              <span>Načítavam zákazníkov…</span>
            </div>
          ) : error ? (
            <p className="customers-error">{error}</p>
          ) : filtered.length === 0 ? (
            <p className="customers-empty">
              {search ? 'Žiadny zákazník nevyhovuje hľadaniu.' : 'Zatiaľ nemáte žiadnych zákazníkov.'}
            </p>
          ) : (
            <div className="items-grid">
              {filtered.map((c) => (
                <button key={c.id} type="button" className="item-card" onClick={() => openItem(c)}>
                  <div className="item-card-top">
                    <span className="item-card-name">{c.name}</span>
                    <span className={`item-card-badge ${c.is_active !== 0 ? 'item-card-badge--active' : 'item-card-badge--inactive'}`}>
                      {c.is_active !== 0 ? 'Aktívny' : 'Neaktívny'}
                    </span>
                  </div>
                  <div className="item-card-meta">
                    {c.ico && <span className="item-card-tag">IČO {c.ico}</span>}
                    {c.city && <span className="item-card-tag">{c.city}</span>}
                    {c.dic && <span className="item-card-tag">DIČ {c.dic}</span>}
                  </div>
                  {c.email && <span className="item-card-sub">{c.email}</span>}
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
              <span className={`drawer-badge ${selected.is_active !== 0 ? 'drawer-badge--active' : 'drawer-badge--inactive'}`}>
                {selected.is_active !== 0 ? 'Aktívny' : 'Neaktívny'}
              </span>
            </DrawerRow>
          </dl>
        ) : (mode === 'edit' || mode === 'create') ? (
          <div className="drawer-form">
            {saveError && <p className="drawer-save-error">{saveError}</p>}
            <div className="drawer-field">
              <label>Meno / Názov *</label>
              <input type="text" value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} placeholder="Meno zákazníka" autoFocus />
            </div>
            <p className="drawer-section-title">Daňové údaje</p>
            <div className="drawer-field-row">
              <div className="drawer-field">
                <label>IČO *</label>
                <input type="text" value={form.ico} onChange={(e) => setForm((f) => ({ ...f, ico: e.target.value }))} placeholder="12345678" />
              </div>
              <div className="drawer-field">
                <label>DIČ</label>
                <input type="text" value={form.dic} onChange={(e) => setForm((f) => ({ ...f, dic: e.target.value }))} placeholder="nepovinné" />
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
              <span>Aktívny zákazník</span>
            </label>
          </div>
        ) : null}
      </DetailDrawer>
    </>
  )
}
