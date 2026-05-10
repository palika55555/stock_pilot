import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { getAuth, getAuthHeaders } from '../utils/auth'
import { API_BASE_FOR_CALLS } from '../config'
import { pavingCalcFromM2 } from '../utils/pavingCalc'
import './sync-pages.css'

const emptyForm = {
  name: '',
  length_mm: '',
  width_mm: '',
  thickness_mm: '',
  pieces_per_layer: '',
  layers_per_pallet: '',
}

export default function PavingStonesPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [form, setForm] = useState(emptyForm)
  const [editId, setEditId] = useState(null)
  const [demoM2, setDemoM2] = useState('10')

  const load = () => {
    if (!auth?.token) return
    setLoading(true)
    setError('')
    fetch(`${API_BASE_FOR_CALLS}/paving-stones`, { headers: getAuthHeaders(auth) })
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error('load'))))
      .then((d) => setRows(Array.isArray(d) ? d : []))
      .catch(() => setError('Načítanie zlyhalo'))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  useEffect(() => { if (auth) load() }, [auth])

  const demoCalc = useMemo(() => {
    if (!editId) return null
    const stone = rows.find((x) => x.id === editId)
    if (!stone) return null
    const m2 = parseFloat(String(demoM2).replace(',', '.'))
    if (!(m2 > 0)) return null
    return pavingCalcFromM2(m2, stone)
  }, [editId, rows, demoM2])

  const onSubmit = (e) => {
    e.preventDefault()
    if (!auth?.token) return
    setError('')
    const body = {
      name: form.name.trim(),
      length_mm: parseFloat(String(form.length_mm).replace(',', '.')),
      width_mm: parseFloat(String(form.width_mm).replace(',', '.')),
      thickness_mm: parseFloat(String(form.thickness_mm).replace(',', '.')),
      pieces_per_layer: parseInt(form.pieces_per_layer, 10),
      layers_per_pallet: parseInt(form.layers_per_pallet, 10),
    }
    if (!body.name || !body.pieces_per_layer || !body.layers_per_pallet) {
      setError('Vyplňte názov a počty.')
      return
    }
    const url = editId ? `${API_BASE_FOR_CALLS}/paving-stones/${editId}` : `${API_BASE_FOR_CALLS}/paving-stones`
    fetch(url, {
      method: editId ? 'PUT' : 'POST',
      headers: getAuthHeaders(auth),
      body: JSON.stringify(body),
    })
      .then((r) => (r.ok ? r.json() : r.json().then((d) => Promise.reject(new Error(d.error || 'Uloženie')))))
      .then(() => {
        setForm(emptyForm)
        setEditId(null)
        load()
      })
      .catch((err) => setError(err.message || 'Chyba'))
  }

  const startEdit = (r) => {
    setEditId(r.id)
    setForm({
      name: r.name || '',
      length_mm: String(r.length_mm ?? ''),
      width_mm: String(r.width_mm ?? ''),
      thickness_mm: String(r.thickness_mm ?? ''),
      pieces_per_layer: String(r.pieces_per_layer ?? ''),
      layers_per_pallet: String(r.layers_per_pallet ?? ''),
    })
  }

  const cancelEdit = () => {
    setEditId(null)
    setForm(emptyForm)
  }

  const remove = (id) => {
    if (!auth?.token || !window.confirm('Zmazať tento typ dlažby?')) return
    fetch(`${API_BASE_FOR_CALLS}/paving-stones/${id}`, { method: 'DELETE', headers: getAuthHeaders(auth) })
      .then((r) => (r.ok ? null : r.json().then((d) => Promise.reject(new Error(d.error)))))
      .then(() => { if (editId === id) cancelEdit(); load() })
      .catch((err) => setError(err.message || 'Zmazanie zlyhalo'))
  }

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main sync-page">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <h2 className="dashboard-overview-title">Typy dlažby (m² výroba)</h2>
        </div>
        <p style={{ color: 'var(--text-muted)', marginBottom: '1rem' }}>
          Definujte rozmery a vrstvy; pri šarži zadáte m² a systém dopočíta kusy ako vo Flutter aplikácii.
        </p>

        {error ? <p className="customers-error">{error}</p> : null}

        <form onSubmit={onSubmit} className="sync-filters" style={{ flexWrap: 'wrap', gap: '0.75rem', alignItems: 'flex-end', marginBottom: '1.5rem' }}>
          <input className="sync-search" placeholder="Názov" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} style={{ flex: '1 1 140px' }} />
          <input className="sync-search" placeholder="Dĺžka mm" value={form.length_mm} onChange={(e) => setForm({ ...form, length_mm: e.target.value })} style={{ width: '100px' }} />
          <input className="sync-search" placeholder="Šírka mm" value={form.width_mm} onChange={(e) => setForm({ ...form, width_mm: e.target.value })} style={{ width: '100px' }} />
          <input className="sync-search" placeholder="Hr. mm" value={form.thickness_mm} onChange={(e) => setForm({ ...form, thickness_mm: e.target.value })} style={{ width: '90px' }} />
          <input className="sync-search" placeholder="ks/vrstva" value={form.pieces_per_layer} onChange={(e) => setForm({ ...form, pieces_per_layer: e.target.value })} style={{ width: '100px' }} />
          <input className="sync-search" placeholder="vrstiev/pal." value={form.layers_per_pallet} onChange={(e) => setForm({ ...form, layers_per_pallet: e.target.value })} style={{ width: '100px' }} />
          <button type="submit" className="dashboard-scan-card" style={{ padding: '0.5rem 1rem' }}>{editId ? 'Uložiť zmeny' : 'Pridať'}</button>
          {editId ? <button type="button" className="dashboard-back" onClick={cancelEdit}>Zrušiť úpravu</button> : null}
        </form>

        {editId && demoCalc ? (
          <p style={{ marginBottom: '1rem', fontSize: '0.9rem' }}>
            Náhľad pri {demoM2} m²:{' '}
            <strong>{demoCalc.totalPieces} ks</strong>, {demoCalc.fullPallets} paliet
            {demoCalc.remainingLayers > 0 ? ` + ${demoCalc.remainingLayers} vrstvy` : ''}, skut. m² {demoCalc.actualM2.toFixed(2)}
            <label style={{ marginLeft: '1rem' }}>
              m²{' '}
              <input className="sync-search" style={{ width: '72px' }} value={demoM2} onChange={(e) => setDemoM2(e.target.value)} />
            </label>
          </p>
        ) : null}

        {loading ? (
          <div className="dashboard-loading"><span className="btn-spinner" aria-hidden="true" /><span>Načítavam…</span></div>
        ) : (
          <ul className="sync-list">
            {rows.map((r) => (
              <li key={r.id} className="sync-list-item">
                <div className="sync-list-item__body">
                  <div className="sync-list-item__top">
                    <span className="sync-list-item__number">{r.name}</span>
                  </div>
                  <span className="sync-list-item__sub">
                    {r.length_mm}×{r.width_mm}×{r.thickness_mm} mm · {r.pieces_per_layer} ks/vrstva · {r.layers_per_pallet} vrstiev/paleta
                  </span>
                  <div style={{ marginTop: '0.5rem', display: 'flex', gap: '0.5rem' }}>
                    <button type="button" className="dashboard-back" onClick={() => startEdit(r)}>Upraviť</button>
                    <button type="button" className="dashboard-back" onClick={() => remove(r.id)}>Zmazať</button>
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </main>
    </div>
  )
}
