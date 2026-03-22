import { useState, useEffect } from 'react'
import { API_BASE_FOR_CALLS } from '../../config'
import { getAuthHeaders } from '../../utils/auth'
import './ProductPricingRulesList.css'

function formatMoney(n) {
  if (n == null || Number.isNaN(Number(n))) return '—'
  return `${Number(n).toLocaleString('sk-SK', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} €`
}

export default function ProductPricingRulesList({ auth, productUniqueId }) {
  const [rules, setRules] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!auth?.token || !productUniqueId) {
      setRules([])
      setLoading(false)
      return
    }
    let cancelled = false
    setLoading(true)
    setError('')
    fetch(
      `${API_BASE_FOR_CALLS}/products/${encodeURIComponent(productUniqueId)}/pricing-rules`,
      { headers: getAuthHeaders(auth) }
    )
      .then((r) => {
        if (!r.ok) throw new Error('Cenník sa nepodarilo načítať')
        return r.json()
      })
      .then((data) => {
        if (!cancelled) setRules(Array.isArray(data) ? data : [])
      })
      .catch((e) => {
        if (!cancelled) setError(e.message || 'Chyba')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => { cancelled = true }
  }, [auth?.token, productUniqueId])

  if (!productUniqueId) return null

  if (loading) {
    return (
      <div className="product-pricing-rules product-pricing-rules--loading">
        <p className="product-pricing-rules__title">Cenník</p>
        <p className="product-pricing-rules__hint">Načítavam…</p>
      </div>
    )
  }

  if (error) {
    return (
      <div className="product-pricing-rules">
        <p className="product-pricing-rules__title">Cenník</p>
        <p className="product-pricing-rules__err">{error}</p>
      </div>
    )
  }

  if (rules.length === 0) {
    return (
      <div className="product-pricing-rules">
        <p className="product-pricing-rules__title">Cenník</p>
        <p className="product-pricing-rules__hint">Žiadne cenové pravidlá (nastavte v aplikácii).</p>
      </div>
    )
  }

  return (
    <div className="product-pricing-rules">
      <p className="product-pricing-rules__title">Cenník</p>
      <ul className="product-pricing-rules__list">
        {rules.map((r) => (
          <li key={r.id ?? `${r.quantity_from}-${r.price}`} className="product-pricing-rules__item">
            <span className="product-pricing-rules__price">{formatMoney(r.price)}</span>
            <span className="product-pricing-rules__meta">
              {r.label ? `${r.label} · ` : ''}
              od {r.quantity_from ?? 1} ks
              {r.quantity_to != null ? ` – ${r.quantity_to} ks` : ''}
              {r.customer_group ? ` · ${r.customer_group}` : ''}
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
}
