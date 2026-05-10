import { useState, useEffect, useCallback } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import './DashboardPage.css'
import './CustomersPage.css'
import './ProductionPage.css'
import { getAuth, getAuthHeaders } from '../utils/auth'
import { API_BASE_FOR_CALLS } from '../config'
import { pavingCalcFromM2 } from '../utils/pavingCalc'

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

function mergeRecipeFromApi(defaultRows, items) {
  const byName = new Map(defaultRows.map((r) => [r.material_name, { ...r }]))
  const extra = []
  for (const item of items) {
    const name = item.material_name
    if (byName.has(name)) {
      byName.get(name).quantity = item.quantity
    } else {
      extra.push({
        material_name: name,
        quantity: item.quantity,
        unit: item.unit || 'kg',
      })
    }
  }
  return [...byName.values(), ...extra]
}

export default function ProductionBatchFormPage() {
  const navigate = useNavigate()
  const { batchId } = useParams()
  const isEdit = Boolean(batchId && String(batchId).match(/^\d+$/))
  const [auth, setAuth] = useState(null)
  const [pavingStones, setPavingStones] = useState([])
  const [pavingStoneId, setPavingStoneId] = useState('')
  const [requestedM2, setRequestedM2] = useState('')
  const [pavingCalc, setPavingCalc] = useState(null)
  const [hasPallets, setHasPallets] = useState(false)
  const [loading, setLoading] = useState(isEdit)
  const [productionDate, setProductionDate] = useState(todayStr())
  const [productType, setProductType] = useState(DEFAULT_PRODUCT_TYPES[0])
  const [quantityProduced, setQuantityProduced] = useState(0)
  const [notes, setNotes] = useState('')
  const [costTotal, setCostTotal] = useState('')
  const [revenueTotal, setRevenueTotal] = useState('')
  const [recipe, setRecipe] = useState(DEFAULT_RECIPE.map((r) => ({ ...r })))
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const loadEdit = useCallback(() => {
    if (!auth?.token || !isEdit) return
    setLoading(true)
    const h = getAuthHeaders(auth)
    Promise.all([
      fetch(`${API_BASE_FOR_CALLS}/batches/${batchId}`, { headers: h }).then((r) => (r.ok ? r.json() : Promise.reject(new Error('Šarža nenájdená')))),
      fetch(`${API_BASE_FOR_CALLS}/batches/${batchId}/recipe`, { headers: h }).then((r) => (r.ok ? r.json() : [])),
      fetch(`${API_BASE_FOR_CALLS}/batches/${batchId}/pallets`, { headers: h }).then((r) => (r.ok ? r.json() : [])),
      fetch(`${API_BASE_FOR_CALLS}/paving-stones`, { headers: h }).then((r) => (r.ok ? r.json() : [])),
    ])
      .then(([batch, rec, pals, stones]) => {
        setPavingStones(Array.isArray(stones) ? stones : [])
        setProductionDate((batch.production_date || '').slice(0, 10))
        setProductType(batch.product_type || DEFAULT_PRODUCT_TYPES[0])
        setQuantityProduced(batch.quantity_produced ?? 0)
        setNotes(batch.notes || '')
        setCostTotal(batch.cost_total != null ? String(batch.cost_total) : '')
        setRevenueTotal(batch.revenue_total != null ? String(batch.revenue_total) : '')
        if (batch.paving_stone_id) {
          setPavingStoneId(String(batch.paving_stone_id))
          setRequestedM2(batch.requested_m2 != null ? String(batch.requested_m2) : '')
        } else {
          setPavingStoneId('')
          setRequestedM2('')
        }
        setHasPallets(Array.isArray(pals) && pals.length > 0)
        setRecipe(mergeRecipeFromApi(DEFAULT_RECIPE, Array.isArray(rec) ? rec : []))
        setPavingCalc(null)
      })
      .catch((err) => setError(err.message || 'Načítanie zlyhalo'))
      .finally(() => setLoading(false))
  }, [auth?.token, isEdit, batchId])

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) {
      navigate('/', { replace: true })
      return
    }
    setAuth(a)
  }, [navigate])

  useEffect(() => {
    if (!auth?.token) return
    if (!isEdit) {
      fetch(`${API_BASE_FOR_CALLS}/paving-stones`, { headers: getAuthHeaders(auth) })
        .then((r) => (r.ok ? r.json() : []))
        .then((rows) => setPavingStones(Array.isArray(rows) ? rows : []))
        .catch(() => setPavingStones([]))
      return
    }
    loadEdit()
  }, [auth?.token, isEdit, loadEdit])

  const selectedStone = pavingStones.find((s) => String(s.id) === String(pavingStoneId)) || null

  useEffect(() => {
    if (!selectedStone || !requestedM2) {
      setPavingCalc(null)
      return
    }
    const m2 = parseFloat(String(requestedM2).replace(',', '.'))
    if (!(m2 > 0)) {
      setPavingCalc(null)
      return
    }
    const c = pavingCalcFromM2(m2, selectedStone)
    setPavingCalc(c)
    if (c) setQuantityProduced(c.totalPieces)
  }, [selectedStone, requestedM2])

  const updateRecipe = (index, field, value) => {
    setRecipe((prev) => prev.map((r, i) => (i === index ? { ...r, [field]: value } : r)))
  }

  const addCustomMaterial = () => {
    setRecipe((prev) => [...prev, { material_name: 'Materiál', unit: 'kg', quantity: 0 }])
  }

  const removeRecipeRow = (index) => {
    setRecipe((prev) => prev.filter((_, i) => i !== index))
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    if (!auth?.token) return
    const usePaving = Boolean(pavingStoneId)
    const qty = parseInt(quantityProduced, 10)
    if (!usePaving && (Number.isNaN(qty) || qty < 0)) {
      setError('Zadajte platný počet vyrobených kusov.')
      return
    }
    if (usePaving) {
      const m2 = parseFloat(String(requestedM2).replace(',', '.'))
      if (!(m2 > 0)) {
        setError('Zadajte požadované m² pre vybranú dlažbu.')
        return
      }
    }
    setError('')
    setSaving(true)
    const body = {
      production_date: productionDate,
      product_type: productType,
      quantity_produced: usePaving ? qty : (Number.isNaN(qty) ? 0 : qty),
      notes: notes.trim() || undefined,
      cost_total: costTotal ? parseFloat(String(costTotal).replace(',', '.')) : undefined,
      revenue_total: revenueTotal ? parseFloat(String(revenueTotal).replace(',', '.')) : undefined,
      recipe: recipe.filter((r) => (parseFloat(r.quantity) || 0) > 0).map((r) => ({
        material_name: r.material_name,
        quantity: parseFloat(r.quantity) || 0,
        unit: r.unit || 'kg',
      })),
    }
    if (usePaving) {
      body.paving_stone_id = parseInt(pavingStoneId, 10)
      body.requested_m2 = parseFloat(String(requestedM2).replace(',', '.'))
    }
    const url = isEdit ? `${API_BASE_FOR_CALLS}/batches/${batchId}` : `${API_BASE_FOR_CALLS}/batches`
    fetch(url, {
      method: isEdit ? 'PUT' : 'POST',
      headers: getAuthHeaders(auth),
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

  if (loading) {
    return (
      <div className="dashboard-page-content">
        <main className="dashboard-main">
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam šaržu…</span>
          </div>
        </main>
      </div>
    )
  }

  const typeOptions = [...DEFAULT_PRODUCT_TYPES]
  if (productType && !typeOptions.includes(productType)) typeOptions.push(productType)

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main customers-main">
        <button type="button" className="dashboard-back" onClick={() => navigate(isEdit ? `/dashboard/production/${batchId}` : '/dashboard/production')} style={{ marginBottom: '0.5rem' }}>
          ← Späť
        </button>
        <h2 className="dashboard-overview-title">{isEdit ? 'Upraviť šaržu' : 'Nová šarža'}</h2>

        <form onSubmit={handleSubmit}>
          <div className="production-create-pallets-form" style={{ marginBottom: '1rem' }}>
            <label>Dátum výroby</label>
            <input
              type="date"
              value={productionDate}
              onChange={(e) => setProductionDate(e.target.value.slice(0, 10))}
              required
            />
            {pavingStones.length > 0 && (
              <>
                <label>Typ dlažby (m²) — voliteľné</label>
                <select
                  value={pavingStoneId}
                  onChange={(e) => {
                    const v = e.target.value
                    setPavingStoneId(v)
                    setPavingCalc(null)
                    if (!v) {
                      setRequestedM2('')
                      return
                    }
                    const st = pavingStones.find((x) => String(x.id) === v)
                    if (st) setProductType(st.name)
                  }}
                  style={{ width: '100%', padding: '0.5rem', marginBottom: '0.75rem', background: 'var(--bg-dark)', color: 'var(--text)', border: '1px solid var(--border)', borderRadius: 8 }}
                >
                  <option value="">— Bez m² / iný výrobok —</option>
                  {pavingStones.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name} ({s.pieces_per_layer} ks/vrstva)
                    </option>
                  ))}
                </select>
                {pavingStoneId ? (
                  <>
                    <label>Požadované m² {hasPallets ? <span style={{ color: '#f87171' }}>(uzamknuté — existujú palety)</span> : null}</label>
                    <input
                      type="text"
                      inputMode="decimal"
                      disabled={hasPallets}
                      value={requestedM2}
                      onChange={(e) => setRequestedM2(e.target.value)}
                      required
                    />
                    {pavingCalc && (
                      <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)', marginTop: '0.35rem' }}>
                        → {pavingCalc.totalPieces} ks · {pavingCalc.fullPallets} paliet
                        {pavingCalc.remainingLayers > 0 ? ` + ${pavingCalc.remainingLayers} vrstvy` : ''} · skutočné m²: {pavingCalc.actualM2.toFixed(2)}
                      </p>
                    )}
                  </>
                ) : null}
              </>
            )}
            {!pavingStoneId ? (
              <>
                <label>Typ výrobku</label>
                <select
                  value={typeOptions.includes(productType) ? productType : typeOptions[0]}
                  onChange={(e) => setProductType(e.target.value)}
                  style={{ width: '100%', padding: '0.5rem', marginBottom: '0.75rem', background: 'var(--bg-dark)', color: 'var(--text)', border: '1px solid var(--border)', borderRadius: 8 }}
                >
                  {typeOptions.map((t) => (
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
              </>
            ) : null}
          </div>

          <div className="production-create-pallets-form" style={{ marginBottom: '1rem' }}>
            <h3 style={{ marginTop: 0 }}>Receptúra (materiály)</h3>
            {recipe.map((r, i) => (
              <div key={`${r.material_name}-${i}`} style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', marginBottom: '0.5rem' }}>
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
                {i >= DEFAULT_RECIPE.length && (
                  <button type="button" className="dashboard-back" style={{ padding: '0.25rem 0.5rem' }} onClick={() => removeRecipeRow(i)}>✕</button>
                )}
              </div>
            ))}
            <button type="button" className="dashboard-back" style={{ marginTop: '0.5rem' }} onClick={addCustomMaterial}>+ Pridať materiál</button>
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
            <input type="text" inputMode="decimal" value={costTotal} onChange={(e) => setCostTotal(e.target.value)} />
            <label>Výnosy (€)</label>
            <input type="text" inputMode="decimal" value={revenueTotal} onChange={(e) => setRevenueTotal(e.target.value)} />
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
