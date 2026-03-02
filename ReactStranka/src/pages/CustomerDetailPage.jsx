import { useState, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import './DashboardPage.css'
import './CustomerDetailPage.css'
import { API_BASE_FOR_CALLS } from '../config'

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
  const [editing, setEditing] = useState(false)
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState('')
  const [form, setForm] = useState({ name: '', ico: '', email: '', address: '', city: '', postal_code: '', dic: '', ic_dph: '', default_vat_rate: 20, is_active: true })

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
        const res = await fetch(`${API_BASE_FOR_CALLS}/customers/${id}`, {
          headers: auth?.token ? { Authorization: auth.token } : {},
        })
        if (res.status === 404) {
          if (!cancelled) setError('Zákazník nebol nájdený')
          return
        }
        if (!res.ok) throw new Error('Načítanie zlyhalo')
        const data = await res.json()
        if (!cancelled) {
          setCustomer(data)
          setForm({
            name: data.name ?? '',
            ico: data.ico ?? '',
            email: data.email ?? '',
            address: data.address ?? '',
            city: data.city ?? '',
            postal_code: data.postal_code ?? '',
            dic: data.dic ?? '',
            ic_dph: data.ic_dph ?? '',
            default_vat_rate: data.default_vat_rate ?? 20,
            is_active: data.is_active !== 0,
          })
        }
      } catch (e) {
        if (!cancelled) setError(e.message || 'Chyba')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    fetchCustomer()
    return () => { cancelled = true }
  }, [auth, id])

  const handleSave = async (e) => {
    e.preventDefault()
    setSaveError('')
    setSaving(true)
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/customers/${id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          ...(auth?.token ? { Authorization: auth.token } : {}),
        },
        body: JSON.stringify({
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
        }),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        setSaveError(data.error || 'Uloženie zlyhalo')
        return
      }
      setCustomer(data)
      setEditing(false)
    } catch (e) {
      setSaveError(e.message || 'Chyba')
    } finally {
      setSaving(false)
    }
  }

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
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
              <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard/customers')} style={{ marginBottom: '0.5rem' }}>← Späť na zoznam</button>
              <h2 className="dashboard-overview-title">{customer.name}</h2>
              <div className="customer-detail-actions">
                {!editing ? (
                  <>
                    <button type="button" className="btn-edit" onClick={() => setEditing(true)}>
                      Upraviť
                    </button>
                    <button type="button" className="btn-back-list" onClick={() => navigate('/dashboard/customers')}>
                      Späť na zoznam
                    </button>
                  </>
                ) : (
                  <>
                    <button type="button" className="btn-back-list" onClick={() => { setEditing(false); setSaveError('') }}>
                      Zrušiť
                    </button>
                  </>
                )}
              </div>
            </div>

            {!editing ? (
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
            ) : (
              <form className="customer-detail-form" onSubmit={handleSave}>
                {saveError && <p className="customer-detail-save-error">{saveError}</p>}
                <label className="customer-form-group">
                  <span>Meno *</span>
                  <input
                    type="text"
                    value={form.name}
                    onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                    required
                    className="customer-form-input"
                  />
                </label>
                <label className="customer-form-group">
                  <span>IČO *</span>
                  <input
                    type="text"
                    value={form.ico}
                    onChange={(e) => setForm((f) => ({ ...f, ico: e.target.value }))}
                    required
                    className="customer-form-input"
                  />
                </label>
                <label className="customer-form-group">
                  <span>Email</span>
                  <input
                    type="email"
                    value={form.email}
                    onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
                    className="customer-form-input"
                  />
                </label>
                <label className="customer-form-group">
                  <span>Adresa</span>
                  <input
                    type="text"
                    value={form.address}
                    onChange={(e) => setForm((f) => ({ ...f, address: e.target.value }))}
                    className="customer-form-input"
                  />
                </label>
                <label className="customer-form-group">
                  <span>Mesto</span>
                  <input
                    type="text"
                    value={form.city}
                    onChange={(e) => setForm((f) => ({ ...f, city: e.target.value }))}
                    className="customer-form-input"
                  />
                </label>
                <label className="customer-form-group">
                  <span>PSČ</span>
                  <input
                    type="text"
                    value={form.postal_code}
                    onChange={(e) => setForm((f) => ({ ...f, postal_code: e.target.value }))}
                    className="customer-form-input"
                  />
                </label>
                <label className="customer-form-group">
                  <span>DIČ</span>
                  <input
                    type="text"
                    value={form.dic}
                    onChange={(e) => setForm((f) => ({ ...f, dic: e.target.value }))}
                    className="customer-form-input"
                  />
                </label>
                <label className="customer-form-group">
                  <span>IČ DPH</span>
                  <input
                    type="text"
                    value={form.ic_dph}
                    onChange={(e) => setForm((f) => ({ ...f, ic_dph: e.target.value }))}
                    className="customer-form-input"
                  />
                </label>
                <label className="customer-form-group">
                  <span>Predvolená DPH %</span>
                  <input
                    type="number"
                    min="0"
                    max="100"
                    value={form.default_vat_rate}
                    onChange={(e) => setForm((f) => ({ ...f, default_vat_rate: e.target.value }))}
                    className="customer-form-input"
                  />
                </label>
                <label className="customer-form-group customer-form-group--checkbox">
                  <input
                    type="checkbox"
                    checked={form.is_active}
                    onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))}
                  />
                  <span>Aktívny zákazník</span>
                </label>
                <div className="customer-form-actions">
                  <button type="submit" className="btn-save" disabled={saving}>
                    {saving ? 'Ukladám...' : 'Uložiť'}
                  </button>
                </div>
              </form>
            )}
          </>
        ) : null}
      </main>
    </div>
  )
}
