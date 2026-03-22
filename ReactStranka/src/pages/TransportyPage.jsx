import { useState, useEffect, useRef, useMemo, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'
import './sync-pages.css'
import './TransportyPage.css'

// ── Helpers ──────────────────────────────────────────────────────────────────

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('sk-SK')
}
function fmtNum(v, dec = 2) {
  return new Intl.NumberFormat('sk-SK', { minimumFractionDigits: dec, maximumFractionDigits: dec }).format(Number(v) || 0)
}
function fmtEur(v) {
  return new Intl.NumberFormat('sk-SK', { style: 'currency', currency: 'EUR' }).format(Number(v) || 0)
}

// Haversine fallback (km)
function haversine(lat1, lon1, lat2, lon2) {
  const R = 6371
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLon = ((lon2 - lon1) * Math.PI) / 180
  const a = Math.sin(dLat / 2) ** 2 + Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

// ── AddressAutocomplete ───────────────────────────────────────────────────────

function AddressAutocomplete({ value, onChange, onSelect, placeholder, label, auth }) {
  const [suggestions, setSuggestions] = useState([])
  const [open, setOpen] = useState(false)
  const [busy, setBusy] = useState(false)
  const timer = useRef(null)
  const cancelled = useRef(false)

  const search = useCallback(async (q) => {
    if (!q || q.length < 2) { setSuggestions([]); return }
    setBusy(true)
    cancelled.current = false
    try {
      const r = await fetch(`${API_BASE_FOR_CALLS}/geocode/search?q=${encodeURIComponent(q)}`, {
        headers: getAuthHeaders(auth),
      })
      if (!cancelled.current && r.ok) {
        const data = await r.json()
        if (!cancelled.current) setSuggestions(Array.isArray(data) ? data.slice(0, 7) : [])
      }
    } catch {}
    if (!cancelled.current) setBusy(false)
  }, [auth])

  const handleChange = (e) => {
    const v = e.target.value
    onChange(v)
    clearTimeout(timer.current)
    timer.current = setTimeout(() => search(v), 320)
    setOpen(true)
  }

  const handleSelect = (item) => {
    // Build a short display name: first part before first comma
    const parts = item.display_name.split(',')
    const shortName = parts.slice(0, 3).join(',').trim()
    onChange(shortName)
    onSelect({
      name: shortName,
      fullName: item.display_name,
      lat: parseFloat(item.lat),
      lon: parseFloat(item.lon),
    })
    setSuggestions([])
    setOpen(false)
  }

  useEffect(() => () => { cancelled.current = true; clearTimeout(timer.current) }, [])

  return (
    <div className="transport-autocomplete transport-field">
      {label && <label className="transport-label">{label}</label>}
      <input
        type="text"
        className="transport-input"
        value={value}
        onChange={handleChange}
        placeholder={placeholder}
        onFocus={() => suggestions.length > 0 && setOpen(true)}
        onBlur={() => { timer.current = setTimeout(() => setOpen(false), 180) }}
        autoComplete="off"
      />
      {open && (busy || suggestions.length > 0) && (
        <ul className="transport-autocomplete__dropdown">
          {busy && suggestions.length === 0 && (
            <li className="transport-autocomplete__loading">Hľadám adresy…</li>
          )}
          {suggestions.map((s, i) => {
            const parts = s.display_name.split(',')
            const name = parts[0]
            const sub = parts.slice(1, 4).join(',').trim()
            return (
              <li key={i} className="transport-autocomplete__item" onMouseDown={() => handleSelect(s)}>
                <div className="transport-autocomplete__item-name">{name}</div>
                {sub && <div className="transport-autocomplete__item-sub">{sub}</div>}
              </li>
            )
          })}
        </ul>
      )}
    </div>
  )
}

// ── LeafletMap ────────────────────────────────────────────────────────────────

function LeafletMap({ origin, dest, routeCoords }) {
  const mapRef = useRef(null)
  const instanceRef = useRef(null)
  const [ready, setReady] = useState(!!window.L)

  useEffect(() => {
    if (window.L) { setReady(true); return }
    const link = document.createElement('link')
    link.rel = 'stylesheet'
    link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
    document.head.appendChild(link)
    const script = document.createElement('script')
    script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'
    script.onload = () => setReady(true)
    document.head.appendChild(script)
    return () => {
      try { document.head.removeChild(link) } catch {}
      try { document.head.removeChild(script) } catch {}
    }
  }, [])

  useEffect(() => {
    if (!ready || !mapRef.current || !origin || !dest) return
    const L = window.L

    if (instanceRef.current) {
      try { instanceRef.current.remove() } catch {}
      instanceRef.current = null
    }

    const centerLat = (origin.lat + dest.lat) / 2
    const centerLon = (origin.lon + dest.lon) / 2
    const map = L.map(mapRef.current).setView([centerLat, centerLon], 8)
    instanceRef.current = map

    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      maxZoom: 19,
    }).addTo(map)

    const dotHtml = (color) =>
      `<div style="width:14px;height:14px;background:${color};border-radius:50%;border:3px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,0.45)"></div>`

    const greenIcon = L.divIcon({ className: '', html: dotHtml('#22c55e'), iconSize: [14, 14], iconAnchor: [7, 7] })
    const redIcon = L.divIcon({ className: '', html: dotHtml('#ef4444'), iconSize: [14, 14], iconAnchor: [7, 7] })

    L.marker([origin.lat, origin.lon], { icon: greenIcon }).bindPopup(`<b>Nakládka</b><br>${origin.name}`).addTo(map)
    L.marker([dest.lat, dest.lon], { icon: redIcon }).bindPopup(`<b>Vykládka</b><br>${dest.name}`).addTo(map)

    if (routeCoords && routeCoords.length > 0) {
      const latlngs = routeCoords.map(([lon, lat]) => [lat, lon])
      L.polyline(latlngs, { color: '#6366f1', weight: 5, opacity: 0.85 }).addTo(map)
    }

    const bounds = L.latLngBounds([[origin.lat, origin.lon], [dest.lat, dest.lon]])
    map.fitBounds(bounds, { padding: [44, 44] })
  }, [ready, origin, dest, routeCoords])

  useEffect(() => () => {
    if (instanceRef.current) { try { instanceRef.current.remove() } catch {} }
  }, [])

  return (
    <div className="transport-map-wrap">
      {!ready && (
        <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)', fontSize: '0.875rem' }}>
          Načítavam mapu…
        </div>
      )}
      <div ref={mapRef} id="transport-leaflet-map" style={{ display: ready ? 'block' : 'none' }} />
    </div>
  )
}

// ── PrintLabel ────────────────────────────────────────────────────────────────

function printLabel(transport) {
  const el = document.getElementById('transport-print-label')
  if (!el) return
  el.innerHTML = `
    <div class="transport-label-sheet">
      <div class="transport-label-sheet__header">
        <div class="transport-label-sheet__company">Stock Pilot – Prepravný štítok</div>
        <div class="transport-label-sheet__type">${transport.isRoundTrip ? 'SPIATOČNÁ' : 'JEDNOSMERNÁ'}</div>
      </div>
      <div class="transport-label-sheet__route">
        <div class="transport-label-sheet__location">
          <div class="transport-label-sheet__location-label">Nakládka (odkiaľ)</div>
          <div class="transport-label-sheet__location-name">${transport.origin}</div>
        </div>
        <div class="transport-label-sheet__arrow">→</div>
        <div class="transport-label-sheet__location">
          <div class="transport-label-sheet__location-label">Vykládka (kam)</div>
          <div class="transport-label-sheet__location-name">${transport.destination}</div>
        </div>
      </div>
      <div class="transport-label-sheet__details">
        <div>
          <div class="transport-label-sheet__detail-label">Vzdialenosť</div>
          <div class="transport-label-sheet__detail-value">${fmtNum(transport.distance, 1)} km</div>
        </div>
        <div>
          <div class="transport-label-sheet__detail-label">Cena / km</div>
          <div class="transport-label-sheet__detail-value">${fmtEur(transport.pricePerKm)}</div>
        </div>
        ${transport.fuelConsumption ? `
        <div>
          <div class="transport-label-sheet__detail-label">Spotreba</div>
          <div class="transport-label-sheet__detail-value">${fmtNum(transport.fuelConsumption, 1)} l/100km</div>
        </div>` : ''}
        ${transport.fuelPrice ? `
        <div>
          <div class="transport-label-sheet__detail-label">Cena nafty</div>
          <div class="transport-label-sheet__detail-value">${fmtEur(transport.fuelPrice)} / l</div>
        </div>` : ''}
        ${transport.fuelCost > 0 ? `
        <div>
          <div class="transport-label-sheet__detail-label">Náklady na palivo</div>
          <div class="transport-label-sheet__detail-value">${fmtEur(transport.fuelCost)}</div>
        </div>` : ''}
        <div>
          <div class="transport-label-sheet__detail-label">Základná cena</div>
          <div class="transport-label-sheet__detail-value">${fmtEur(transport.baseCost)}</div>
        </div>
        ${transport.notes ? `
        <div style="grid-column:1/-1">
          <div class="transport-label-sheet__detail-label">Poznámka</div>
          <div class="transport-label-sheet__detail-value">${transport.notes}</div>
        </div>` : ''}
      </div>
      <div class="transport-label-sheet__total">
        <div class="transport-label-sheet__total-label">Celkové náklady</div>
        <div class="transport-label-sheet__total-value">${fmtEur(transport.totalCost)}</div>
      </div>
      <div class="transport-label-sheet__footer">Vygenerované: ${new Date().toLocaleDateString('sk-SK')} | Stock Pilot</div>
    </div>
  `
  window.print()
}

// ── Calculator Tab ─────────────────────────────────────────────────────────────

function CalculatorTab({ auth }) {
  const [origin, setOrigin] = useState('')
  const [originCoords, setOriginCoords] = useState(null)
  const [dest, setDest] = useState('')
  const [destCoords, setDestCoords] = useState(null)

  const [pricePerKm, setPricePerKm] = useState('1.50')
  const [fuelConsumption, setFuelConsumption] = useState('8.0')
  const [fuelPrice, setFuelPrice] = useState('1.55')
  const [isRoundTrip, setIsRoundTrip] = useState(false)
  const [notes, setNotes] = useState('')

  const [customers, setCustomers] = useState([])
  const [selectedCustomer, setSelectedCustomer] = useState('')

  const [calculating, setCalculating] = useState(false)
  const [result, setResult] = useState(null) // { distance, baseCost, fuelCost, totalCost, routeCoords }
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const [calcError, setCalcError] = useState('')

  // Load customers for address auto-fill
  useEffect(() => {
    fetch(`${API_BASE_FOR_CALLS}/customers`, { headers: getAuthHeaders(auth) })
      .then(r => r.ok ? r.json() : null)
      .then(d => { if (Array.isArray(d)) setCustomers(d) })
      .catch(() => {})
  }, [auth])

  // Auto-fill destination when customer is selected
  const handleCustomerChange = (e) => {
    const id = e.target.value
    setSelectedCustomer(id)
    if (!id) return
    const c = customers.find(c => String(c.id) === id)
    if (!c) return
    const parts = [c.address, c.city, c.postal_code].filter(Boolean)
    if (parts.length > 0) {
      setDest(parts.join(', '))
      setDestCoords(null)
    }
  }

  const handleCalculate = async () => {
    if (!origin.trim() || !dest.trim()) {
      setCalcError('Vyplňte miesto nakládky a vykládky.')
      return
    }
    setCalcError('')
    setCalculating(true)
    setResult(null)
    setSaved(false)

    try {
      let oCoords = originCoords
      let dCoords = destCoords

      // Geocode if not yet resolved
      if (!oCoords) {
        const r = await fetch(`${API_BASE_FOR_CALLS}/geocode/search?q=${encodeURIComponent(origin)}`, { headers: getAuthHeaders(auth) })
        const data = await r.json()
        if (Array.isArray(data) && data.length > 0) {
          oCoords = { lat: parseFloat(data[0].lat), lon: parseFloat(data[0].lon), name: origin }
          setOriginCoords(oCoords)
        }
      }
      if (!dCoords) {
        const r = await fetch(`${API_BASE_FOR_CALLS}/geocode/search?q=${encodeURIComponent(dest)}`, { headers: getAuthHeaders(auth) })
        const data = await r.json()
        if (Array.isArray(data) && data.length > 0) {
          dCoords = { lat: parseFloat(data[0].lat), lon: parseFloat(data[0].lon), name: dest }
          setDestCoords(dCoords)
        }
      }

      if (!oCoords || !dCoords) {
        setCalcError('Nepodarilo sa nájsť zadané adresy. Skúste zadať presnejšie mesto alebo obec.')
        setCalculating(false)
        return
      }

      // Get route from OSRM
      let distance = null
      let routeCoords = null
      try {
        const r = await fetch(
          `${API_BASE_FOR_CALLS}/route/osrm?fromLon=${oCoords.lon}&fromLat=${oCoords.lat}&toLon=${dCoords.lon}&toLat=${dCoords.lat}`,
          { headers: getAuthHeaders(auth) }
        )
        const data = await r.json()
        if (data?.routes?.length > 0) {
          distance = data.routes[0].distance / 1000 // m → km
          const geo = data.routes[0].geometry
          if (geo?.coordinates) routeCoords = geo.coordinates
        }
      } catch {}

      // Fallback to Haversine
      if (!distance || distance <= 0) {
        distance = haversine(oCoords.lat, oCoords.lon, dCoords.lat, dCoords.lon)
      }

      if (isRoundTrip) distance *= 2

      const km = distance
      const pkm = parseFloat(pricePerKm) || 0
      const fc = parseFloat(fuelConsumption) || 0
      const fp = parseFloat(fuelPrice) || 0

      const baseCost = km * pkm
      const fuelCost = fc > 0 && fp > 0 ? (km * fc / 100) * fp : 0
      const totalCost = baseCost + fuelCost

      setResult({ distance: km, baseCost, fuelCost, totalCost, routeCoords, oCoords, dCoords })
    } catch (e) {
      setCalcError(`Chyba pri výpočte: ${e.message}`)
    }
    setCalculating(false)
  }

  const handleSave = async () => {
    if (!result) return
    setSaving(true)
    try {
      const body = {
        origin: origin.trim(),
        destination: dest.trim(),
        distance: result.distance,
        is_round_trip: isRoundTrip,
        price_per_km: parseFloat(pricePerKm) || 0,
        fuel_consumption: parseFloat(fuelConsumption) || null,
        fuel_price: parseFloat(fuelPrice) || null,
        base_cost: result.baseCost,
        fuel_cost: result.fuelCost,
        total_cost: result.totalCost,
        notes: notes.trim() || null,
      }
      const r = await fetch(`${API_BASE_FOR_CALLS}/transports`, {
        method: 'POST',
        headers: { ...getAuthHeaders(auth), 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
      if (r.ok) setSaved(true)
      else setCalcError('Uloženie zlyhalo.')
    } catch (e) {
      setCalcError(`Chyba: ${e.message}`)
    }
    setSaving(false)
  }

  const handlePrint = () => {
    if (!result) return
    printLabel({
      origin: origin.trim(),
      destination: dest.trim(),
      distance: result.distance,
      isRoundTrip,
      pricePerKm: parseFloat(pricePerKm) || 0,
      fuelConsumption: parseFloat(fuelConsumption) || null,
      fuelPrice: parseFloat(fuelPrice) || null,
      baseCost: result.baseCost,
      fuelCost: result.fuelCost,
      totalCost: result.totalCost,
      notes: notes.trim(),
    })
  }

  return (
    <div>
      {/* ── Addresses ── */}
      <div className="transport-card">
        <p className="transport-card__title">📍 Trasa</p>

        {/* Customer auto-fill */}
        {customers.length > 0 && (
          <div className="transport-customer-row" style={{ marginBottom: '1rem' }}>
            <div className="transport-field" style={{ flex: 1 }}>
              <label className="transport-label">Auto-vyplniť adresu zákazníka</label>
              <select className="transport-select" value={selectedCustomer} onChange={handleCustomerChange}>
                <option value="">— Vybrať zákazníka —</option>
                {customers.map(c => (
                  <option key={c.id} value={c.id}>{c.name || `Zákazník #${c.id}`}</option>
                ))}
              </select>
            </div>
          </div>
        )}

        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.875rem' }}>
          <AddressAutocomplete
            label="Miesto nakládky (odkiaľ)"
            placeholder="Zadajte mesto, obec, ulicu…"
            value={origin}
            onChange={(v) => { setOrigin(v); setOriginCoords(null) }}
            onSelect={(s) => setOriginCoords(s)}
            auth={auth}
          />
          <AddressAutocomplete
            label="Miesto vykládky (kam)"
            placeholder="Zadajte mesto, obec, ulicu…"
            value={dest}
            onChange={(v) => { setDest(v); setDestCoords(null) }}
            onSelect={(s) => setDestCoords(s)}
            auth={auth}
          />
        </div>

        {/* Route preview strip */}
        {(originCoords || destCoords) && (
          <div className="transport-route-strip" style={{ marginTop: '0.875rem' }}>
            <div className="transport-route-strip__dot transport-route-strip__dot--green" />
            <div className="transport-route-strip__label" title={origin}>{origin || '—'}</div>
            <div className="transport-route-strip__arrow">→</div>
            <div className="transport-route-strip__dot transport-route-strip__dot--red" />
            <div className="transport-route-strip__label" title={dest}>{dest || '—'}</div>
          </div>
        )}
      </div>

      {/* ── Parameters ── */}
      <div className="transport-card">
        <p className="transport-card__title">⚙️ Parametre</p>
        <div className="transport-grid-3">
          <div className="transport-field">
            <label className="transport-label">Cena / km (€)</label>
            <input type="number" className="transport-input" value={pricePerKm} onChange={e => setPricePerKm(e.target.value)} step="0.01" min="0" />
          </div>
          <div className="transport-field">
            <label className="transport-label">Spotreba (l / 100 km)</label>
            <input type="number" className="transport-input" value={fuelConsumption} onChange={e => setFuelConsumption(e.target.value)} step="0.1" min="0" />
          </div>
          <div className="transport-field">
            <label className="transport-label">Cena nafty (€ / l)</label>
            <input type="number" className="transport-input" value={fuelPrice} onChange={e => setFuelPrice(e.target.value)} step="0.01" min="0" />
          </div>
        </div>

        <div style={{ marginTop: '0.875rem' }}>
          <label className="transport-checkbox-row">
            <input type="checkbox" checked={isRoundTrip} onChange={e => setIsRoundTrip(e.target.checked)} />
            Cesta tam aj späť (zdvojnásobí vzdialenosť)
          </label>
        </div>

        <div className="transport-field" style={{ marginTop: '0.875rem' }}>
          <label className="transport-label">Poznámka</label>
          <input type="text" className="transport-input" value={notes} onChange={e => setNotes(e.target.value)} placeholder="Voliteľná poznámka k preprave…" />
        </div>
      </div>

      {calcError && (
        <div style={{ color: '#f87171', fontSize: '0.875rem', marginBottom: '0.75rem', padding: '0.6rem 0.875rem', background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.25)', borderRadius: 8 }}>
          {calcError}
        </div>
      )}

      <button className="transport-calc-btn" onClick={handleCalculate} disabled={calculating}>
        {calculating ? <><div className="transport-spinner" /> Vypočítavam…</> : '🚚 Vypočítať náklady'}
      </button>

      {/* ── Results ── */}
      {result && (
        <div className="transport-card" style={{ marginTop: '1.25rem' }}>
          <p className="transport-card__title">📊 Výsledky</p>

          <div className="transport-results">
            <div className="transport-result-item">
              <div className="transport-result-item__label">Vzdialenosť</div>
              <div className="transport-result-item__value">{fmtNum(result.distance, 1)} km</div>
            </div>
            <div className="transport-result-item">
              <div className="transport-result-item__label">Základná cena</div>
              <div className="transport-result-item__value">{fmtEur(result.baseCost)}</div>
            </div>
            {result.fuelCost > 0 && (
              <div className="transport-result-item">
                <div className="transport-result-item__label">Náklady na palivo</div>
                <div className="transport-result-item__value">{fmtEur(result.fuelCost)}</div>
              </div>
            )}
            <div className="transport-result-item transport-result-item--total">
              <div className="transport-result-item__label">Celkové náklady</div>
              <div className="transport-result-item__value">{fmtEur(result.totalCost)}</div>
            </div>
          </div>

          {result.fuelCost > 0 && (
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '1rem' }}>
              Spotreba: {fmtNum(result.distance * (parseFloat(fuelConsumption) || 0) / 100, 1)} l
              &nbsp;·&nbsp; Cena nafty: {fmtEur(parseFloat(fuelPrice) || 0)}/l
            </div>
          )}

          <div className="transport-actions">
            <button className="transport-btn transport-btn--primary" onClick={handleSave} disabled={saving || saved}>
              {saving ? '…' : saved ? '✓ Uložené' : '💾 Uložiť'}
            </button>
            <button className="transport-btn transport-btn--secondary" onClick={handlePrint}>
              🖨️ Prepravný štítok
            </button>
          </div>

          {saved && (
            <div className="transport-saved-banner">
              ✓ Transport bol uložený a bude viditeľný v histórii.
            </div>
          )}

          {/* Map */}
          {result.oCoords && result.dCoords && (
            <LeafletMap
              origin={result.oCoords}
              dest={result.dCoords}
              routeCoords={result.routeCoords}
            />
          )}
        </div>
      )}
    </div>
  )
}

// ── History Tab ───────────────────────────────────────────────────────────────

function HistoryTab({ auth }) {
  const [transports, setTransports] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    fetch(`${API_BASE_FOR_CALLS}/transports/all`, { headers: getAuthHeaders(auth) })
      .then(r => r.ok ? r.json() : Promise.reject(r.status))
      .then(d => { if (!cancelled) setTransports(Array.isArray(d?.transports) ? d.transports : []) })
      .catch(e => { if (!cancelled) setError(`Načítanie zlyhalo (${e})`) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [auth])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return transports
    return transports.filter(t => `${t.origin ?? ''} ${t.destination ?? ''}`.toLowerCase().includes(q))
  }, [transports, search])

  if (loading) return (
    <div className="dashboard-loading">
      <span className="btn-spinner" aria-hidden="true" />
      <span>Načítavam históriu…</span>
    </div>
  )

  if (error) return <p className="customers-error">{error}</p>

  return (
    <div>
      <div className="sync-filters">
        <input
          type="search"
          className="sync-search"
          placeholder="Hľadať podľa miesta odchodu alebo destinácie…"
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
      </div>

      {filtered.length === 0 ? (
        <div className="sync-empty">
          {transports.length === 0
            ? 'Žiadne transporty. Vypočítajte ich pomocou kalkulátora.'
            : 'Žiadne výsledky pre zadaný filter.'}
        </div>
      ) : (
        <ul className="sync-list">
          {[...filtered].reverse().map((t) => (
            <li key={t.id} className="sync-list-item">
              <div className="sync-list-item__body">
                <div className="sync-list-item__top">
                  <span className="sync-list-item__number">
                    {t.origin || '?'} → {t.destination || '?'}
                  </span>
                  {t.is_round_trip ? (
                    <span className="sync-badge sync-badge--blue">Spiatočná</span>
                  ) : (
                    <span className="sync-badge sync-badge--gray">Jednosmerná</span>
                  )}
                </div>
                <div className="sync-list-item__meta">
                  <span>Vzdialenosť: <span className="sync-list-item__accent">{fmtNum(t.distance, 1)} km</span></span>
                  <span>Celkové náklady: <span className="sync-list-item__accent">{fmtEur(t.total_cost)}</span></span>
                  {Number(t.fuel_cost) > 0 && <span>Palivo: {fmtEur(t.fuel_cost)}</span>}
                  {Number(t.price_per_km) > 0 && <span>Cena/km: {fmtEur(t.price_per_km)}</span>}
                  <span>Dátum: {fmtDate(t.created_at)}</span>
                  {t.notes && (
                    <span style={{ maxWidth: 260, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {t.notes}
                    </span>
                  )}
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', padding: '0 1rem' }}>
                <button
                  type="button"
                  className="transport-btn transport-btn--secondary"
                  style={{ fontSize: '0.75rem', padding: '0.4rem 0.75rem' }}
                  onClick={() => printLabel({
                    origin: t.origin,
                    destination: t.destination,
                    distance: t.distance,
                    isRoundTrip: !!t.is_round_trip,
                    pricePerKm: t.price_per_km,
                    fuelConsumption: t.fuel_consumption,
                    fuelPrice: t.fuel_price,
                    baseCost: t.base_cost,
                    fuelCost: t.fuel_cost,
                    totalCost: t.total_cost,
                    notes: t.notes,
                  })}
                >
                  🖨️ Štítok
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

// ── Main Page ─────────────────────────────────────────────────────────────────

export default function TransportyPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [tab, setTab] = useState('calc')

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      {/* Hidden print label container */}
      <div id="transport-print-label" aria-hidden="true" />

      <main className="dashboard-main sync-page" style={{ maxWidth: 900 }}>
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <h2 className="dashboard-overview-title">Transporty</h2>
        </div>

        <div className="transport-tabs">
          <button
            type="button"
            className={`transport-tab ${tab === 'calc' ? 'transport-tab--active' : ''}`}
            onClick={() => setTab('calc')}
          >
            🚚 Kalkulátor
          </button>
          <button
            type="button"
            className={`transport-tab ${tab === 'history' ? 'transport-tab--active' : ''}`}
            onClick={() => setTab('history')}
          >
            📋 História
          </button>
        </div>

        {tab === 'calc' && <CalculatorTab auth={auth} />}
        {tab === 'history' && <HistoryTab auth={auth} />}
      </main>
    </div>
  )
}
