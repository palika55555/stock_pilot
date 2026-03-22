import { useState, useEffect, useRef, useMemo, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'
import './TransportyPage.css'

// ── Formatters ────────────────────────────────────────────────────────────────
const fmtDate = (iso) => iso ? new Date(iso).toLocaleDateString('sk-SK') : '—'
const fmtNum  = (v, d = 2) => new Intl.NumberFormat('sk-SK', { minimumFractionDigits: d, maximumFractionDigits: d }).format(Number(v) || 0)
const fmtEur  = (v) => new Intl.NumberFormat('sk-SK', { style: 'currency', currency: 'EUR' }).format(Number(v) || 0)

function haversine(lat1, lon1, lat2, lon2) {
  const R = 6371
  const dL = ((lat2 - lat1) * Math.PI) / 180
  const dG = ((lon2 - lon1) * Math.PI) / 180
  const a = Math.sin(dL / 2) ** 2 + Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dG / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

// ── AnimatedNumber ────────────────────────────────────────────────────────────
function AnimatedNumber({ target, format = (v) => v, duration = 700 }) {
  const [val, setVal] = useState(0)
  const prev = useRef(0)
  useEffect(() => {
    const from = prev.current
    prev.current = target
    const t0 = performance.now()
    const raf = (now) => {
      const p = Math.min((now - t0) / duration, 1)
      const e = 1 - (1 - p) ** 3
      setVal(from + (target - from) * e)
      if (p < 1) requestAnimationFrame(raf)
    }
    requestAnimationFrame(raf)
  }, [target, duration])
  return <>{format(val)}</>
}

// ── AddressField (autocomplete) ───────────────────────────────────────────────
function AddressField({ value, onChange, onSelect, placeholder, dotClass, auth }) {
  const [suggestions, setSuggestions] = useState([])
  const [open, setOpen] = useState(false)
  const [busy, setBusy] = useState(false)
  const [focused, setFocused] = useState(false)
  const timer = useRef(null)
  const cancelled = useRef(false)

  const search = useCallback(async (q) => {
    if (!q || q.length < 2) { setSuggestions([]); return }
    setBusy(true); cancelled.current = false
    try {
      const r = await fetch(`${API_BASE_FOR_CALLS}/geocode/search?q=${encodeURIComponent(q)}`, { headers: getAuthHeaders(auth) })
      if (!cancelled.current && r.ok) {
        const d = await r.json()
        if (!cancelled.current) setSuggestions(Array.isArray(d) ? d.slice(0, 7) : [])
      }
    } catch {}
    if (!cancelled.current) setBusy(false)
  }, [auth])

  const handleChange = (e) => {
    const v = e.target.value
    onChange(v)
    clearTimeout(timer.current)
    timer.current = setTimeout(() => search(v), 300)
    setOpen(true)
  }

  const handleSelect = (item) => {
    const parts = item.display_name.split(',')
    const short = parts.slice(0, 3).join(',').trim()
    onChange(short)
    onSelect({ name: short, lat: parseFloat(item.lat), lon: parseFloat(item.lon) })
    setSuggestions([]); setOpen(false)
  }

  useEffect(() => () => { cancelled.current = true; clearTimeout(timer.current) }, [])

  return (
    <div className="tp-location-field">
      <div className="tp-location-input-wrap">
        <div className={`tp-location-dot ${dotClass}${focused ? ' tp-location-dot--active' : ''}`} />
        <input
          type="text"
          className="tp-location-input"
          value={value}
          onChange={handleChange}
          placeholder={placeholder}
          onFocus={() => { setFocused(true); if (suggestions.length > 0) setOpen(true) }}
          onBlur={() => { setFocused(false); timer.current = setTimeout(() => setOpen(false), 180) }}
          autoComplete="off"
        />
      </div>
      {open && (busy || suggestions.length > 0) && (
        <ul className="tp-autocomplete">
          {busy && suggestions.length === 0 && (
            <li className="tp-autocomplete__loading">
              <div className="tp-autocomplete__spinner" /> Hľadám…
            </li>
          )}
          {suggestions.map((s, i) => {
            const p = s.display_name.split(',')
            return (
              <li key={i} className="tp-autocomplete__item" onMouseDown={() => handleSelect(s)}>
                <div className="tp-autocomplete__item-name">{p[0]}</div>
                {p.length > 1 && <div className="tp-autocomplete__item-sub">{p.slice(1, 4).join(',').trim()}</div>}
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
  const ref = useRef(null)
  const instance = useRef(null)
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
    if (!ready || !ref.current || !origin || !dest) return
    const L = window.L
    if (instance.current) { try { instance.current.remove() } catch {} instance.current = null }

    const centerLat = (origin.lat + dest.lat) / 2
    const centerLon = (origin.lon + dest.lon) / 2
    const map = L.map(ref.current).setView([centerLat, centerLon], 8)
    instance.current = map

    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
      attribution: '© OpenStreetMap © CARTO',
      maxZoom: 19,
      subdomains: 'abcd',
    }).addTo(map)

    const dot = (color, glow) => L.divIcon({
      className: '',
      html: `<div style="width:14px;height:14px;background:${color};border-radius:50%;border:2.5px solid rgba(255,255,255,0.9);box-shadow:0 0 0 4px ${glow},0 0 16px ${color}"></div>`,
      iconSize: [14, 14],
      iconAnchor: [7, 7],
    })

    L.marker([origin.lat, origin.lon], { icon: dot('#22c55e', 'rgba(34,197,94,0.25)') })
      .bindPopup(`<b>Nakládka</b><br>${origin.name}`).addTo(map)
    L.marker([dest.lat, dest.lon], { icon: dot('#ef4444', 'rgba(239,68,68,0.25)') })
      .bindPopup(`<b>Vykládka</b><br>${dest.name}`).addTo(map)

    if (routeCoords?.length > 0) {
      const pts = routeCoords.map(([lon, lat]) => [lat, lon])
      L.polyline(pts, { color: '#818cf8', weight: 5, opacity: 0.9, lineCap: 'round', lineJoin: 'round' }).addTo(map)
      // glow layer
      L.polyline(pts, { color: '#6366f1', weight: 12, opacity: 0.18 }).addTo(map)
    }

    map.fitBounds(L.latLngBounds([[origin.lat, origin.lon], [dest.lat, dest.lon]]), { padding: [50, 50] })
  }, [ready, origin, dest, routeCoords])

  useEffect(() => () => { if (instance.current) { try { instance.current.remove() } catch {} } }, [])

  return (
    <div className="tp-map-wrap">
      {!ready && (
        <div className="tp-map-loading">
          <div className="tp-spinner" />
          <span>Načítavam mapu…</span>
        </div>
      )}
      <div ref={ref} id="transport-leaflet-map" style={{ display: ready ? 'block' : 'none' }} />
    </div>
  )
}

// ── Print label ───────────────────────────────────────────────────────────────
function printLabel(t) {
  const el = document.getElementById('transport-print-label')
  if (!el) return
  el.innerHTML = `
    <div class="tp-label-sheet">
      <div class="tp-label-sheet__header">
        <div class="tp-label-sheet__company">Stock Pilot – Prepravný štítok</div>
        <div class="tp-label-sheet__type">${t.isRoundTrip ? 'SPIATOČNÁ' : 'JEDNOSMERNÁ'}</div>
      </div>
      <div class="tp-label-sheet__route">
        <div class="tp-label-sheet__location">
          <div class="tp-label-sheet__location-label">Nakládka (odkiaľ)</div>
          <div class="tp-label-sheet__location-name">${t.origin}</div>
        </div>
        <div class="tp-label-sheet__arrow">→</div>
        <div class="tp-label-sheet__location">
          <div class="tp-label-sheet__location-label">Vykládka (kam)</div>
          <div class="tp-label-sheet__location-name">${t.destination}</div>
        </div>
      </div>
      <div class="tp-label-sheet__details">
        <div><div class="tp-label-sheet__detail-label">Vzdialenosť</div><div class="tp-label-sheet__detail-value">${fmtNum(t.distance, 1)} km</div></div>
        <div><div class="tp-label-sheet__detail-label">Cena / km</div><div class="tp-label-sheet__detail-value">${fmtEur(t.pricePerKm)}</div></div>
        ${t.fuelConsumption ? `<div><div class="tp-label-sheet__detail-label">Spotreba</div><div class="tp-label-sheet__detail-value">${fmtNum(t.fuelConsumption, 1)} l/100km</div></div>` : ''}
        ${t.fuelPrice ? `<div><div class="tp-label-sheet__detail-label">Cena nafty</div><div class="tp-label-sheet__detail-value">${fmtEur(t.fuelPrice)} / l</div></div>` : ''}
        ${t.fuelCost > 0 ? `<div><div class="tp-label-sheet__detail-label">Náklady na palivo</div><div class="tp-label-sheet__detail-value">${fmtEur(t.fuelCost)}</div></div>` : ''}
        <div><div class="tp-label-sheet__detail-label">Základná cena</div><div class="tp-label-sheet__detail-value">${fmtEur(t.baseCost)}</div></div>
        ${t.notes ? `<div style="grid-column:1/-1"><div class="tp-label-sheet__detail-label">Poznámka</div><div class="tp-label-sheet__detail-value">${t.notes}</div></div>` : ''}
      </div>
      <div class="tp-label-sheet__total">
        <div class="tp-label-sheet__total-label">Celkové náklady</div>
        <div class="tp-label-sheet__total-value">${fmtEur(t.totalCost)}</div>
      </div>
      <div class="tp-label-sheet__footer">Vygenerované: ${new Date().toLocaleDateString('sk-SK')} | Stock Pilot</div>
    </div>`
  window.print()
}

// ── Calculator Tab ─────────────────────────────────────────────────────────────
function CalculatorTab({ auth }) {
  const [origin, setOrigin]         = useState('')
  const [originC, setOriginC]       = useState(null)
  const [dest, setDest]             = useState('')
  const [destC, setDestC]           = useState(null)
  const [pricePerKm, setPricePerKm] = useState('1.50')
  const [fuelL, setFuelL]           = useState('8.0')
  const [fuelP, setFuelP]           = useState('1.55')
  const [roundTrip, setRoundTrip]   = useState(false)
  const [notes, setNotes]           = useState('')
  const [customers, setCustomers]   = useState([])
  const [custId, setCustId]         = useState('')
  const [busy, setBusy]             = useState(false)
  const [result, setResult]         = useState(null)
  const [saving, setSaving]         = useState(false)
  const [saved, setSaved]           = useState(false)
  const [err, setErr]               = useState('')

  useEffect(() => {
    fetch(`${API_BASE_FOR_CALLS}/customers`, { headers: getAuthHeaders(auth) })
      .then(r => r.ok ? r.json() : null)
      .then(d => { if (Array.isArray(d)) setCustomers(d) })
      .catch(() => {})
  }, [auth])

  const handleCustChange = (e) => {
    setCustId(e.target.value)
    if (!e.target.value) return
    const c = customers.find(c => String(c.id) === e.target.value)
    if (c) {
      const addr = [c.address, c.city, c.postal_code].filter(Boolean).join(', ')
      if (addr) { setDest(addr); setDestC(null) }
    }
  }

  const handleSwap = () => {
    setOrigin(dest); setOriginC(destC)
    setDest(origin); setDestC(originC)
  }

  const calc = async () => {
    if (!origin.trim() || !dest.trim()) { setErr('Vyplňte miesto nakládky a vykládky.'); return }
    setErr(''); setBusy(true); setResult(null); setSaved(false)
    try {
      let oC = originC, dC = destC
      if (!oC) {
        const r = await fetch(`${API_BASE_FOR_CALLS}/geocode/search?q=${encodeURIComponent(origin)}`, { headers: getAuthHeaders(auth) })
        const d = await r.json()
        if (Array.isArray(d) && d.length) { oC = { lat: parseFloat(d[0].lat), lon: parseFloat(d[0].lon), name: origin }; setOriginC(oC) }
      }
      if (!dC) {
        const r = await fetch(`${API_BASE_FOR_CALLS}/geocode/search?q=${encodeURIComponent(dest)}`, { headers: getAuthHeaders(auth) })
        const d = await r.json()
        if (Array.isArray(d) && d.length) { dC = { lat: parseFloat(d[0].lat), lon: parseFloat(d[0].lon), name: dest }; setDestC(dC) }
      }
      if (!oC || !dC) { setErr('Nepodarilo sa nájsť zadané adresy.'); setBusy(false); return }

      let dist = null, routeCoords = null
      try {
        const r = await fetch(
          `${API_BASE_FOR_CALLS}/route/osrm?fromLon=${oC.lon}&fromLat=${oC.lat}&toLon=${dC.lon}&toLat=${dC.lat}`,
          { headers: getAuthHeaders(auth) }
        )
        const d = await r.json()
        if (d?.routes?.length) {
          dist = d.routes[0].distance / 1000
          routeCoords = d.routes[0].geometry?.coordinates ?? null
        }
      } catch {}

      if (!dist || dist <= 0) dist = haversine(oC.lat, oC.lon, dC.lat, dC.lon)
      if (roundTrip) dist *= 2

      const pkm   = parseFloat(pricePerKm) || 0
      const fc    = parseFloat(fuelL) || 0
      const fp    = parseFloat(fuelP) || 0
      const base  = dist * pkm
      const fuel  = fc > 0 && fp > 0 ? (dist * fc / 100) * fp : 0
      const total = base + fuel
      setResult({ distance: dist, baseCost: base, fuelCost: fuel, totalCost: total, routeCoords, oC, dC })
    } catch (e) { setErr(`Chyba: ${e.message}`) }
    setBusy(false)
  }

  const save = async () => {
    if (!result) return
    setSaving(true)
    try {
      const r = await fetch(`${API_BASE_FOR_CALLS}/transports`, {
        method: 'POST',
        headers: { ...getAuthHeaders(auth), 'Content-Type': 'application/json' },
        body: JSON.stringify({
          origin: origin.trim(), destination: dest.trim(),
          distance: result.distance, is_round_trip: roundTrip,
          price_per_km: parseFloat(pricePerKm) || 0,
          fuel_consumption: parseFloat(fuelL) || null,
          fuel_price: parseFloat(fuelP) || null,
          base_cost: result.baseCost, fuel_cost: result.fuelCost, total_cost: result.totalCost,
          notes: notes.trim() || null,
        }),
      })
      if (r.ok) setSaved(true); else setErr('Uloženie zlyhalo.')
    } catch (e) { setErr(`Chyba: ${e.message}`) }
    setSaving(false)
  }

  return (
    <>
      {/* ── Route card ── */}
      <div className="tp-card">
        <div className="tp-card-header">
          <div className="tp-card-icon">📍</div>
          <div>
            <div className="tp-card-title">Trasa</div>
            <div className="tp-card-sub">Zadajte miesto nakládky a vykládky</div>
          </div>
        </div>

        {customers.length > 0 && (
          <div className="tp-customer-row">
            <label>Auto-vyplniť adresu:</label>
            <select className="tp-customer-select" value={custId} onChange={handleCustChange}>
              <option value="">— Zákazník —</option>
              {customers.map(c => (
                <option key={c.id} value={c.id}>{c.name || `#${c.id}`}</option>
              ))}
            </select>
          </div>
        )}

        <div className="tp-locations">
          <AddressField
            value={origin}
            onChange={(v) => { setOrigin(v); setOriginC(null) }}
            onSelect={(s) => setOriginC(s)}
            placeholder="Nakládka – mesto, obec, ulica…"
            dotClass="tp-location-dot--from"
            auth={auth}
          />
          <div className="tp-route-connector">
            <div className="tp-route-connector__line" />
            <button type="button" className="tp-route-connector__swap" onClick={handleSwap} title="Vymeniť trasu">⇅</button>
          </div>
          <AddressField
            value={dest}
            onChange={(v) => { setDest(v); setDestC(null) }}
            onSelect={(s) => setDestC(s)}
            placeholder="Vykládka – mesto, obec, ulica…"
            dotClass="tp-location-dot--to"
            auth={auth}
          />
        </div>
      </div>

      {/* ── Params card ── */}
      <div className="tp-card">
        <div className="tp-card-header">
          <div className="tp-card-icon">⚙️</div>
          <div>
            <div className="tp-card-title">Parametre prepravy</div>
            <div className="tp-card-sub">Nastavte ceny a spotrebu</div>
          </div>
        </div>

        <div className="tp-params-grid">
          <div className="tp-field">
            <label className="tp-label">Cena / km (€)</label>
            <input type="number" className="tp-input" value={pricePerKm} onChange={e => setPricePerKm(e.target.value)} step="0.01" min="0" />
          </div>
          <div className="tp-field">
            <label className="tp-label">Spotreba (l / 100 km)</label>
            <input type="number" className="tp-input" value={fuelL} onChange={e => setFuelL(e.target.value)} step="0.1" min="0" />
          </div>
          <div className="tp-field">
            <label className="tp-label">Cena nafty (€ / l)</label>
            <input type="number" className="tp-input" value={fuelP} onChange={e => setFuelP(e.target.value)} step="0.01" min="0" />
          </div>

          {/* Round trip toggle – full row */}
          <div
            className={`tp-toggle-row${roundTrip ? ' tp-toggle-row--on' : ''}`}
            onClick={() => setRoundTrip(r => !r)}
          >
            <div className="tp-toggle-label">
              <span className="tp-toggle-icon">🔄</span>
              Cesta tam aj späť
              {roundTrip && <span className="tp-toggle-badge">×2 km</span>}
            </div>
            <div className={`tp-switch${roundTrip ? ' tp-switch--on' : ''}`} />
          </div>
        </div>

        <div className="tp-notes-field">
          <div className="tp-field">
            <label className="tp-label">Poznámka</label>
            <input type="text" className="tp-input" value={notes} onChange={e => setNotes(e.target.value)} placeholder="Voliteľná poznámka…" />
          </div>
        </div>

        {err && <div className="tp-error">⚠ {err}</div>}

        <div style={{ position: 'relative' }}>
          <button className="tp-calc-btn" onClick={calc} disabled={busy}>
            <div className="tp-calc-btn__glow" />
            {busy ? <><div className="tp-spinner" /> Vypočítavam…</> : <>🚚 Vypočítať náklady</>}
          </button>
        </div>
      </div>

      {/* ── Results card ── */}
      {result && (
        <div className="tp-card">
          <div className="tp-card-header">
            <div className="tp-card-icon">📊</div>
            <div>
              <div className="tp-card-title">Výsledky</div>
              <div className="tp-card-sub">
                {origin.split(',')[0]} → {dest.split(',')[0]}
                {roundTrip ? ' · spiatočná' : ' · jednosmerná'}
              </div>
            </div>
          </div>

          <div className="tp-distance-badge">
            🛣 <AnimatedNumber target={result.distance} format={v => fmtNum(v, 1)} /> km
          </div>

          <div className="tp-results-grid">
            <div className="tp-result-card">
              <span className="tp-result-icon">🛣</span>
              <div className="tp-result-label">Vzdialenosť</div>
              <div className="tp-result-value">
                <AnimatedNumber target={result.distance} format={v => fmtNum(v, 1)} /> km
              </div>
            </div>
            <div className="tp-result-card">
              <span className="tp-result-icon">💶</span>
              <div className="tp-result-label">Základná cena</div>
              <div className="tp-result-value">
                <AnimatedNumber target={result.baseCost} format={fmtEur} />
              </div>
            </div>
            {result.fuelCost > 0 && (
              <div className="tp-result-card">
                <span className="tp-result-icon">⛽</span>
                <div className="tp-result-label">Náklady na palivo</div>
                <div className="tp-result-value">
                  <AnimatedNumber target={result.fuelCost} format={fmtEur} />
                </div>
              </div>
            )}
            <div className="tp-result-card tp-result-card--total">
              <span className="tp-result-icon">✅</span>
              <div className="tp-result-label">Celkové náklady</div>
              <div className="tp-result-value">
                <AnimatedNumber target={result.totalCost} format={fmtEur} />
              </div>
            </div>
          </div>

          {result.fuelCost > 0 && (
            <div className="tp-fuel-summary">
              <span>⛽ Spotreba: <strong>{fmtNum(result.distance * (parseFloat(fuelL) || 0) / 100, 1)} l</strong></span>
              <span>💧 Cena nafty: <strong>{fmtEur(parseFloat(fuelP) || 0)}/l</strong></span>
            </div>
          )}

          <div className="tp-actions">
            <button
              className={`tp-btn tp-btn--save${saved ? ' saved' : ''}`}
              onClick={save}
              disabled={saving || saved}
            >
              {saved ? '✓ Uložené' : saving ? '…' : '💾 Uložiť preprava'}
            </button>
            <button className="tp-btn tp-btn--print" onClick={() => printLabel({
              origin: origin.trim(), destination: dest.trim(),
              distance: result.distance, isRoundTrip: roundTrip,
              pricePerKm: parseFloat(pricePerKm) || 0,
              fuelConsumption: parseFloat(fuelL) || null,
              fuelPrice: parseFloat(fuelP) || null,
              baseCost: result.baseCost, fuelCost: result.fuelCost,
              totalCost: result.totalCost, notes: notes.trim(),
            })}>
              🖨️ Prepravný štítok
            </button>
          </div>

          {saved && (
            <div className="tp-saved-banner">✓ Transport uložený – nájdete ho v záložke História.</div>
          )}

          {result.oC && result.dC && (
            <LeafletMap origin={result.oC} dest={result.dC} routeCoords={result.routeCoords} />
          )}
        </div>
      )}
    </>
  )
}

// ── History Tab ───────────────────────────────────────────────────────────────
function HistoryTab({ auth }) {
  const [transports, setTransports] = useState([])
  const [loading, setLoading]       = useState(true)
  const [error, setError]           = useState('')
  const [search, setSearch]         = useState('')

  useEffect(() => {
    let cancelled = false
    fetch(`${API_BASE_FOR_CALLS}/transports/all`, { headers: getAuthHeaders(auth) })
      .then(r => r.ok ? r.json() : Promise.reject(r.status))
      .then(d => { if (!cancelled) setTransports(Array.isArray(d?.transports) ? d.transports : []) })
      .catch(e => { if (!cancelled) setError(`Načítanie zlyhalo (${e})`) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [auth])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return [...transports].reverse()
    return [...transports].reverse().filter(t =>
      `${t.origin ?? ''} ${t.destination ?? ''}`.toLowerCase().includes(q)
    )
  }, [transports, search])

  if (loading) return (
    <div className="tp-empty">
      <div className="tp-spinner" style={{ width: 28, height: 28, borderWidth: 3 }} />
    </div>
  )

  if (error) return <div className="tp-error">⚠ {error}</div>

  return (
    <>
      <div className="tp-search-wrap">
        <span className="tp-search-icon">🔍</span>
        <input
          type="search"
          className="tp-search"
          placeholder="Hľadať trasu…"
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
      </div>

      {filtered.length === 0 ? (
        <div className="tp-empty">
          <div className="tp-empty__icon">🚚</div>
          <div className="tp-empty__text">
            {transports.length === 0
              ? 'Žiadne transporty. Vypočítajte prvý v záložke Kalkulátor.'
              : 'Žiadne výsledky pre zadaný filter.'}
          </div>
        </div>
      ) : (
        <div>
          {filtered.map((t) => (
            <div key={t.id} className="tp-history-item">
              <div className="tp-history-route">
                <div className="tp-history-route__main">
                  <div className="tp-history-route__from">{t.origin || '?'}</div>
                  <div className="tp-history-route__arrow">→</div>
                  <div className="tp-history-route__to">{t.destination || '?'}</div>
                  <span className={`tp-history-meta__badge ${t.is_round_trip ? 'tp-history-meta__badge--round' : 'tp-history-meta__badge--one'}`}>
                    {t.is_round_trip ? '⇄ spiatočná' : '→ jednosmerná'}
                  </span>
                </div>
                <div className="tp-history-meta">
                  <span>🛣 {fmtNum(t.distance, 1)} km</span>
                  {Number(t.fuel_cost) > 0 && <span>⛽ {fmtEur(t.fuel_cost)}</span>}
                  {Number(t.price_per_km) > 0 && <span>{fmtEur(t.price_per_km)}/km</span>}
                  <span>📅 {fmtDate(t.created_at)}</span>
                  {t.notes && <span style={{ fontStyle: 'italic' }}>{t.notes}</span>}
                </div>
              </div>

              <div className="tp-history-cost">
                <div className="tp-history-cost__total">{fmtEur(t.total_cost)}</div>
                <div className="tp-history-cost__km">{fmtNum(t.distance, 0)} km</div>
              </div>

              <div className="tp-history-actions">
                <button
                  className="tp-btn tp-btn--print"
                  style={{ padding: '0.45rem 0.75rem', fontSize: '0.8rem' }}
                  onClick={() => printLabel({
                    origin: t.origin, destination: t.destination,
                    distance: t.distance, isRoundTrip: !!t.is_round_trip,
                    pricePerKm: t.price_per_km, fuelConsumption: t.fuel_consumption,
                    fuelPrice: t.fuel_price, baseCost: t.base_cost,
                    fuelCost: t.fuel_cost, totalCost: t.total_cost, notes: t.notes,
                  })}
                >
                  🖨️
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  )
}

// ── Main Page ─────────────────────────────────────────────────────────────────
export default function TransportyPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [tab, setTab]   = useState('calc')

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  if (!auth) return null

  return (
    <div className="tp-page">
      {/* Hidden print label */}
      <div id="transport-print-label" aria-hidden="true" />

      <div className="tp-inner">
        {/* Header */}
        <div className="tp-header">
          <button type="button" className="tp-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <div className="tp-title-wrap">
            <div className="tp-eyebrow">Stock Pilot</div>
            <h1 className="tp-title">Doprava</h1>
          </div>
        </div>

        {/* Tabs */}
        <div className="tp-tabs">
          <button
            type="button"
            className={`tp-tab ${tab === 'calc' ? 'tp-tab--active' : ''}`}
            onClick={() => setTab('calc')}
          >
            <span className="tp-tab-icon">🧮</span> Kalkulátor
          </button>
          <button
            type="button"
            className={`tp-tab ${tab === 'history' ? 'tp-tab--active' : ''}`}
            onClick={() => setTab('history')}
          >
            <span className="tp-tab-icon">📋</span> História
          </button>
        </div>

        {tab === 'calc'    && <CalculatorTab auth={auth} />}
        {tab === 'history' && <HistoryTab auth={auth} />}
      </div>
    </div>
  )
}
