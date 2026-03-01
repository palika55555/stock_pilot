import { useState, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import './DashboardPage.css'
import './CustomersPage.css'
import './ProductionPage.css'
import { API_BASE_FOR_CALLS } from '../config'

const DEFAULT_PRODUCT_TYPES = ['Zamková dlažba', 'Tvárnice', 'Obrubníky', 'Dlažobné kostky', 'Iné']

const DEFAULT_RECIPE = [
  { material_name: 'Voda', unit: 'l', quantity: 0 },
  { material_name: 'Plastifikátor', unit: 'kg', quantity: 0 },
  { material_name: 'Cement', unit: 'kg', quantity: 0 },
  { material_name: 'Štrk', unit: 'kg', quantity: 0 },
  { material_name: 'Štrk 0–4 mm', unit: 'kg', quantity: 0 },
  { material_name: 'Štrk 4–8 mm', unit: 'kg', quantity: 0 },
  { material_name: 'Štrk 8–16 mm', unit: 'kg', quantity: 0 },
  { material_name: 'Štrk 16–32 mm', unit: 'kg', quantity: 0 },
]

function todayStr() {
  return new Date().toISOString().slice(0, 10)
}

export default function ProductionBatchFormPage() {
  const navigate = useNavigate()
  const { date } = useParams()
  const [auth, setAuth] = useState(null)
  const [productionDate, setProductionDate] = useState(date || todayStr())
  const [productType, setProductType] = useState(DEFAULT_PRODUCT_TYPES[0])
  const [quantityProduced, setQuantityProduced] = useState(0)
  const [notes, setNotes] = useState('')
  const [costTotal, setCostTotal] = useState('')
  const [revenueTotal, setRevenueTotal] = useState('')
  const [recipe, setRecipe] = useState(DEFAULT_RECIPE.map((r) => ({ ...r })))
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

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
    if (date) setProductionDate(date)
  }, [navigate, date])

  const updateRecipe = (index, field, value) => {
    setRecipe((prev) => {
      const next = prev.map((r, i) => (i === index ? { ...r, [field]: value } : r))
      return next
    })
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    if (!auth?.token) return
    const qty = parseInt(quantityProduced, 10)
    if (Number.isNaN(qty) || qty < 0) {
      setError('Zadajte platný počet vyrobených kusov.')
      return
    }
    setError('')
    setSaving(true)
    const body = {
      production_date: productionDate,
      product_type: productType,
      quantity_produced: qty,
      notes: notes.trim() || undefined,
      cost_total: costTotal ? parseFloat(costTotal.replace(',', '.')) : undefined,
      revenue_total: revenueTotal ? parseFloat(revenueTotal.replace(',', '.')) : undefined,
      recipe: recipe.filter((r) => (parseFloat(r.quantity) || 0) > 0).map((r) => ({
        material_name: r.material_name,
        quantity: parseFloat(r.quantity) || 0,
        unit: r.unit || 'kg',
      })),
    }
    fetch(`${API_BASE_FOR_CALLS}/batches`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: auth.token,
      },
      body: JSON.stringify(body),
    })
      .then((res) => {
        if (!res.ok) return res.json().then((data) => { throw new Error(data.error || 'Uloženie zlyhalo') })
        return res.json()
      })
      .then((batch) => {
        navigate(`/dashboard/production/${batch.id}`, { replace: true })
      })
      .catch((err) => {
        setError(err.message || 'Chyba pri ukladaní')
        setSaving(false)
      })
  }

  if (!auth) return null

  return (
    <div className="dashboard-page">
      <header className="dashboard-header">
        <div className="dashboard-brand">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard/production')}>
            ←
          </button>
          <span className="dashboard-logo-label">STOCK</span>
          <h1 className="dashboard-logo-title">PILOT</h1>
        </div>
      </header>

      <main className="dashboard-main customers-main">
        <h2 className="dashboard-overview-title">Nová šarža</h2>

        <form onSubmit={handleSubmit}>
          <div className="production-create-pallets-form" style={{ marginBottom: '1rem' }}>
            <label>Dátum výroby</label>
            <input
              type="date"
              value={productionDate}
              onChange={(e) => setProductionDate(e.target.value.slice(0, 10))}
              required
            />
            <label>Typ výrobku</label>
            <select
              value={productType}
              onChange={(e) => setProductType(e.target.value)}
              style={{ width: '100%', padding: '0.5rem', marginBottom: '0.75rem', background: 'var(--bg-dark)', color: 'var(--text)', border: '1px solid var(--border)', borderRadius: 8 }}
            >
              {DEFAULT_PRODUCT_TYPES.map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
            <label>Počet vyrobených kusov</label>
            <input
              type="number"
              min="0"
              value={quantityProduced || ''}
              onChange={(e) => setQuantityProduced(e.target.value)}
              required
            />
          </div>

          <div className="production-create-pallets-form" style={{ marginBottom: '1rem' }}>
            <h3 style={{ marginTop: 0 }}>Receptúra (materiály)</h3>
            {recipe.map((r, i) => (
              <div key={i} style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', marginBottom: '0.5rem' }}>
                <input
                  type="text"
                  value={r.material_name}
                  onChange={(e) => updateRecipe(i, 'material_name', e.target.value)}
                  style={{ flex: 2 }}
                  placeholder="Materiál"
                />
                <input
                  type="text"
                  inputMode="decimal"
                  value={r.quantity || ''}
                  onChange={(e) => updateRecipe(i, 'quantity', e.target.value)}
                  style={{ width: '80px' }}
                  placeholder="0"
                />
                <span style={{ color: 'var(--text-muted)' }}>{r.unit}</span>
              </div>
            ))}
          </div>

          <div className="production-create-pallets-form" style={{ marginBottom: '1rem' }}>
            <label>Poznámky</label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={2}
              style={{ width: '100%', padding: '0.5rem', background: 'var(--bg-dark)', color: 'var(--text)', border: '1px solid var(--border)', borderRadius: 8, resize: 'vertical' }}
            />
            <label>Náklady (€)</label>
            <input
              type="text"
              inputMode="decimal"
              value={costTotal}
              onChange={(e) => setCostTotal(e.target.value)}
            />
            <label>Výnosy (€)</label>
            <input
              type="text"
              inputMode="decimal"
              value={revenueTotal}
              onChange={(e) => setRevenueTotal(e.target.value)}
            />
          </div>

          {error && <p style={{ color: '#f87171', marginBottom: '1rem' }}>{error}</p>}

          <button type="submit" className="production-create-pallets-form button" disabled={saving} style={{ width: '100%', padding: '0.75rem', marginTop: '0.5rem' }}>
            {saving ? 'Ukladám...' : 'Uložiť šaržu'}
          </button>
        </form>
      </main>
    </div>
  )
}
