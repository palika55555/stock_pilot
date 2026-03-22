import { useState, useEffect, useRef, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { Html5Qrcode, Html5QrcodeSupportedFormats } from 'html5-qrcode'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'
import './ScanProductPage.css'

const BARCODE_FORMATS = [
  Html5QrcodeSupportedFormats.EAN_13,
  Html5QrcodeSupportedFormats.EAN_8,
  Html5QrcodeSupportedFormats.UPC_A,
  Html5QrcodeSupportedFormats.UPC_E,
  Html5QrcodeSupportedFormats.CODE_128,
  Html5QrcodeSupportedFormats.CODE_39,
  Html5QrcodeSupportedFormats.CODE_93,
  Html5QrcodeSupportedFormats.ITF,
  Html5QrcodeSupportedFormats.QR_CODE,
]

export default function ScanProductPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [scanning, setScanning] = useState(false)
  const [error, setError] = useState(null)
  const [lastScanned, setLastScanned] = useState(null)
  const [showResult, setShowResult] = useState(false)
  const [productResult, setProductResult] = useState(null) // null | 'loading' | 'not_found' | 'batch' | 'pallet' | product
  const [batchResult, setBatchResult] = useState(null) // { id, product_type, quantity_produced, production_date }
  const [palletResult, setPalletResult] = useState(null) // { id, product_type, quantity, status } + customers for assign
  const [assignOpen, setAssignOpen] = useState(false)
  const [productsList, setProductsList] = useState([])
  const [assignSearch, setAssignSearch] = useState('')
  const [assignLoading, setAssignLoading] = useState(false)
  const [assignSuccess, setAssignSuccess] = useState(false)
  const scannerRef = useRef(null)
  const containerId = 'scan-product-reader'

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) {
      navigate('/', { replace: true })
      return
    }
    setAuth(a)
  }, [navigate])

  const fetchProductByBarcode = useCallback(async (code) => {
    if (!auth?.token) return null
    const res = await fetch(
      `${API_BASE_FOR_CALLS}/products/by-barcode?code=${encodeURIComponent(code)}`,
      { headers: getAuthHeaders(auth) }
    )
    if (res.status === 404) return 'not_found'
    if (!res.ok) throw new Error('API chyba')
    return res.json()
  }, [auth?.token])

  const parseBatchOrPallet = useCallback((code) => {
    const s = (code || '').toString().trim()
    if (s.startsWith('STOCKPILOT_BATCH:')) {
      const id = parseInt(s.slice('STOCKPILOT_BATCH:'.length), 10)
      return { type: 'batch', id: Number.isNaN(id) ? null : id }
    }
    if (s.startsWith('STOCKPILOT_PALLET:')) {
      const id = parseInt(s.slice('STOCKPILOT_PALLET:'.length), 10)
      return { type: 'pallet', id: Number.isNaN(id) ? null : id }
    }
    return null
  }, [])

  useEffect(() => {
    if (!showResult || !lastScanned || !auth?.token) return
    const bp = parseBatchOrPallet(lastScanned)
    if (bp) {
      setProductResult(bp.type)
      setBatchResult(null)
      setPalletResult(null)
      if (bp.type === 'batch' && bp.id) {
        fetch(`${API_BASE_FOR_CALLS}/batches/${bp.id}`, { headers: getAuthHeaders(auth) })
          .then((r) => {
            if (r.ok) return r.json()
            if (r.status === 404) return fetch(`${API_BASE_FOR_CALLS}/batches/by-local/${bp.id}`, { headers: getAuthHeaders(auth) }).then((r2) => (r2.ok ? r2.json() : null))
            return null
          })
          .then((data) => { setBatchResult(data || { notFound: true }) })
          .catch(() => { setBatchResult({ notFound: true }) })
      }
      if (bp.type === 'pallet' && bp.id) {
        const fetchPallet = () =>
          fetch(`${API_BASE_FOR_CALLS}/pallets/${bp.id}`, { headers: getAuthHeaders(auth) })
            .then((r) => {
              if (r.ok) return r.json()
              if (r.status === 404) return fetch(`${API_BASE_FOR_CALLS}/pallets/by-local/${bp.id}`, { headers: getAuthHeaders(auth) }).then((r2) => (r2.ok ? r2.json() : null))
              return null
            })
        Promise.all([
          fetchPallet(),
          fetch(`${API_BASE_FOR_CALLS}/customers`, { headers: getAuthHeaders(auth) }).then((r) => (r.ok ? r.json() : [])),
        ])
          .then(([pallet, customers]) => {
            setPalletResult(pallet ? { pallet, customers: Array.isArray(customers) ? customers : [] } : { notFound: true, customers: Array.isArray(customers) ? customers : [] })
          })
          .catch(() => { setPalletResult({ notFound: true, customers: [] }) })
      }
      return
    }
    setProductResult('loading')
    setBatchResult(null)
    setPalletResult(null)
    let cancelled = false
    fetchProductByBarcode(lastScanned)
      .then((data) => {
        if (!cancelled) setProductResult(data === null ? 'not_found' : data)
      })
      .catch(() => {
        if (!cancelled) setProductResult('not_found')
      })
    return () => { cancelled = true }
  }, [showResult, lastScanned, auth?.token, fetchProductByBarcode, parseBatchOrPallet])

  useEffect(() => {
    if (!auth) return
    let html5QrCode = null

    async function startScanner() {
      try {
        setError(null)
        html5QrCode = new Html5Qrcode(containerId, {
          formatsToSupport: BARCODE_FORMATS,
          verbose: false,
        })
        await html5QrCode.start(
          { facingMode: 'environment' },
          {
            fps: 10,
            qrbox: { width: 250, height: 150 },
            aspectRatio: 1.0,
          },
          (decodedText) => {
            if (html5QrCode && html5QrCode.isScanning) {
              html5QrCode.pause()
            }
            setLastScanned(decodedText)
            setShowResult(true)
            setProductResult(null)
            setScanning(false)
          },
          () => {}
        )
        scannerRef.current = html5QrCode
        setScanning(true)
      } catch (err) {
        console.error(err)
        setError(
          err.name === 'NotAllowedError'
            ? 'Pre skenovanie je potrebný prístup ku kamere. Povoľte kameru v nastaveniach prehliadača.'
            : 'Nepodarilo sa spustiť kameru. Skontrolujte povolenia alebo použite zariadenie s kamerou.'
        )
      }
    }

    startScanner()
    return () => {
      if (scannerRef.current && scannerRef.current.isScanning) {
        scannerRef.current.stop().catch(() => {})
      }
      scannerRef.current = null
    }
  }, [auth])

  useEffect(() => {
    if (!assignOpen || !auth?.token) return
    let cancelled = false
    setAssignLoading(true)
    const search = assignSearch.trim().toLowerCase()
    const url = search
      ? `${API_BASE_FOR_CALLS}/products?search=${encodeURIComponent(assignSearch)}`
      : `${API_BASE_FOR_CALLS}/products`
    fetch(url, { headers: getAuthHeaders(auth) })
      .then((res) => res.ok ? res.json() : [])
      .then((list) => { if (!cancelled) setProductsList(Array.isArray(list) ? list : []) })
      .catch(() => { if (!cancelled) setProductsList([]) })
      .finally(() => { if (!cancelled) setAssignLoading(false) })
    return () => { cancelled = true }
  }, [assignOpen, assignSearch, auth?.token])

  const handleScanAgain = () => {
    setShowResult(false)
    setLastScanned(null)
    setProductResult(null)
    setBatchResult(null)
    setPalletResult(null)
    setAssignSuccess(false)
    if (scannerRef.current && !scannerRef.current.isScanning) {
      scannerRef.current.resume()
    }
    setScanning(true)
  }

  const [palletAssignCustomerId, setPalletAssignCustomerId] = useState('')
  const [palletAssigning, setPalletAssigning] = useState(false)
  const handleAssignPalletToCustomer = () => {
    const cid = parseInt(palletAssignCustomerId, 10)
    const pid = palletResult?.pallet?.id
    if (!auth?.token || Number.isNaN(cid) || !pid) return
    setPalletAssigning(true)
    fetch(`${API_BASE_FOR_CALLS}/pallets/${pid}/assign`, {
      method: 'PUT',
      headers: getAuthHeaders(auth),
      body: JSON.stringify({ customer_id: cid }),
    })
      .then((r) => {
        if (!r.ok) return r.json().then((d) => { throw new Error(d.error || 'Chyba') })
        setAssignSuccess(true)
        setPalletResult((prev) => prev ? { ...prev, pallet: { ...prev.pallet, status: 'U zákazníka', customer_id: cid } } : null)
      })
      .catch((err) => alert(err.message))
      .finally(() => setPalletAssigning(false))
  }

  const handleAssignToProduct = (product) => {
    if (!auth?.token || !lastScanned) return
    const uniqueId = product.unique_id
    setAssignLoading(true)
    fetch(`${API_BASE_FOR_CALLS}/products/${encodeURIComponent(uniqueId)}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        ...getAuthHeaders(auth),
      },
      body: JSON.stringify({ ean: lastScanned }),
    })
      .then((res) => {
        if (!res.ok) throw new Error('Uloženie zlyhalo')
        return res.json()
      })
      .then((updated) => {
        setProductResult(updated)
        setAssignOpen(false)
        setAssignSuccess(true)
      })
      .catch(() => setAssignOpen(false))
      .finally(() => setAssignLoading(false))
  }

  const handleBack = () => {
    navigate('/dashboard')
  }

  if (!auth) return null

  return (
    <div className="scan-product-page">
      <header className="scan-product-header">
        <button type="button" className="scan-product-back" onClick={handleBack} aria-label="Späť">
          ← Späť
        </button>
        <h1 className="scan-product-title">Skenovať tovar</h1>
        <p className="scan-product-subtitle">Namiřte kameru na čiarový kód alebo QR kód</p>
      </header>

      <main className="scan-product-main">
        {error ? (
          <div className="scan-product-error">
            <p>{error}</p>
            <p className="scan-product-error-hint">
              Na mobile otvorte stránku v prehliadači (Chrome, Safari) a povoľte prístup ku kamere.
            </p>
          </div>
        ) : (
          <>
            <div id={containerId} className="scan-product-reader" />
            {!scanning && (
              <div className="scan-product-paused">
                <p>Skenovanie pozastavené – zobrazuje sa výsledok.</p>
              </div>
            )}
          </>
        )}

        {showResult && lastScanned && (
          <div className="scan-product-result" role="dialog" aria-labelledby="scan-result-title">
            <h2 id="scan-result-title" className="scan-product-result-title">
              Naskenovaný kód
            </h2>
            <p className="scan-product-result-code">Kód: {lastScanned}</p>

            {productResult === 'loading' && (
              <p className="scan-product-result-loading">Načítavam produkt zo skladu…</p>
            )}
            {productResult === 'batch' && (
              <>
                <div className="scan-product-result-row">
                  <span>Šarža (výroba)</span>
                  <strong>
                    {batchResult?.notFound ? 'Šarža nebola nájdená (sync z aplikácie alebo vytvorte na webe)' : batchResult ? `${batchResult.product_type} – ${batchResult.quantity_produced} ks` : 'Načítavam…'}
                  </strong>
                </div>
                {batchResult && (
                  <div className="scan-product-result-actions">
                    {!batchResult.notFound && (
                      <button
                        type="button"
                        className="scan-product-btn-primary"
                        onClick={() => { navigate(`/dashboard/production/${batchResult.id}`); setShowResult(false) }}
                      >
                        Otvoriť detail šarže
                      </button>
                    )}
                    <button type="button" className="scan-product-btn-secondary" onClick={handleScanAgain}>
                      Skenovať ďalej
                    </button>
                  </div>
                )}
              </>
            )}
            {productResult === 'pallet' && (
              <>
                <div className="scan-product-result-row">
                  <span>Paleta</span>
                  <strong>
                    {palletResult?.notFound ? 'Paleta nebola nájdená (sync z aplikácie)' : palletResult?.pallet
                      ? `${palletResult.pallet.product_type} – ${palletResult.pallet.quantity} ks (${palletResult.pallet.status})`
                      : 'Načítavam…'}
                  </strong>
                </div>
                {palletResult?.pallet && palletResult.pallet.status !== 'U zákazníka' && palletResult.customers?.length > 0 && (
                  <div className="scan-product-assign-sheet" style={{ marginTop: '1rem', padding: '0.5rem 0' }}>
                    <label className="scan-product-result-hint">Priradiť zákazníkovi (predaj):</label>
                    <select
                      value={palletAssignCustomerId}
                      onChange={(e) => setPalletAssignCustomerId(e.target.value)}
                      style={{ width: '100%', padding: '0.5rem', marginTop: '0.5rem', marginBottom: '0.5rem' }}
                    >
                      <option value="">— Vyberte zákazníka —</option>
                      {palletResult.customers.map((c) => (
                        <option key={c.id} value={c.id}>{c.name}</option>
                      ))}
                    </select>
                    <button
                      type="button"
                      className="scan-product-btn-primary"
                      disabled={!palletAssignCustomerId || palletAssigning}
                      onClick={handleAssignPalletToCustomer}
                    >
                      {palletAssigning ? 'Priraďujem...' : 'Priradiť zákazníkovi'}
                    </button>
                  </div>
                )}
                {assignSuccess && <p className="scan-product-result-success">Paleta priradená zákazníkovi.</p>}
                {(palletResult?.pallet || palletResult?.notFound) && (
                  <div className="scan-product-result-actions">
                    <button type="button" className="scan-product-btn-secondary" onClick={handleScanAgain}>
                      Skenovať ďalej
                    </button>
                    <button type="button" className="scan-product-btn-secondary" onClick={handleBack}>
                      Späť na prehľad
                    </button>
                  </div>
                )}
              </>
            )}
            {productResult === 'not_found' && (
              <>
                <div className="scan-product-result-row">
                  <span>Produkt</span>
                  <strong className="scan-product-result-not-found">Nenájdený</strong>
                </div>
                <p className="scan-product-result-hint">
                  Priraďte tento kód k produktu podľa PLU alebo názvu (v aplikácii alebo tu).
                </p>
                <div className="scan-product-result-actions">
                  <button
                    type="button"
                    className="scan-product-btn-primary"
                    onClick={() => setAssignOpen(true)}
                  >
                    Priradiť k produktu
                  </button>
                  <button type="button" className="scan-product-btn-secondary" onClick={handleScanAgain}>
                    Skenovať ďalej
                  </button>
                  <button type="button" className="scan-product-btn-secondary" onClick={handleBack}>
                    Späť na prehľad
                  </button>
                </div>
              </>
            )}
            {productResult && productResult !== 'loading' && productResult !== 'not_found' && productResult !== 'batch' && productResult !== 'pallet' && typeof productResult === 'object' && (
              <>
                <div className="scan-product-result-row">
                  <span>Produkt</span>
                  <strong>{productResult.name}</strong>
                </div>
                <div className="scan-product-result-row">
                  <span>Na sklade</span>
                  <strong>{productResult.qty ?? 0} {productResult.unit || 'ks'}</strong>
                </div>
                {assignSuccess && (
                  <p className="scan-product-result-success">EAN bol priradený tomuto produktu.</p>
                )}
                <div className="scan-product-result-actions">
                  <button
                    type="button"
                    className="scan-product-btn-primary"
                    onClick={() => {
                      const q =
                        productResult.ean ||
                        productResult.plu ||
                        productResult.name ||
                        lastScanned ||
                        ''
                      navigate(`/dashboard/products?search=${encodeURIComponent(String(q).trim())}`)
                      setShowResult(false)
                    }}
                  >
                    Otvoriť v zozname produktov
                  </button>
                  <button type="button" className="scan-product-btn-secondary" onClick={handleScanAgain}>
                    Skenovať ďalej
                  </button>
                  <button type="button" className="scan-product-btn-secondary" onClick={handleBack}>
                    Späť na prehľad
                  </button>
                </div>
              </>
            )}
          </div>
        )}

        {assignOpen && (
          <div className="scan-product-assign-overlay" role="dialog" aria-label="Vybrať produkt">
            <div className="scan-product-assign-sheet">
              <div className="scan-product-assign-header">
                <h3>Priradiť kód „{lastScanned}” k produktu</h3>
                <button
                  type="button"
                  className="scan-product-assign-close"
                  onClick={() => setAssignOpen(false)}
                  aria-label="Zavrieť"
                >
                  ×
                </button>
              </div>
              <input
                type="text"
                className="scan-product-assign-search"
                placeholder="Hľadať podľa názvu alebo PLU…"
                value={assignSearch}
                onChange={(e) => setAssignSearch(e.target.value)}
                autoFocus
              />
              <div className="scan-product-assign-list">
                {assignLoading && productsList.length === 0 && (
                  <p className="scan-product-result-loading">Načítavam zoznam…</p>
                )}
                {!assignLoading && productsList.length === 0 && (
                  <p className="scan-product-result-hint">Žiadne produkty alebo žiadny výsledok.</p>
                )}
                {productsList.map((p) => (
                  <button
                    key={`${p.unique_id}-${p.warehouse_id ?? ''}`}
                    type="button"
                    className="scan-product-assign-item"
                    onClick={() => handleAssignToProduct(p)}
                    disabled={assignLoading}
                  >
                    <span className="scan-product-assign-item-name">{p.name}</span>
                    <span className="scan-product-assign-item-meta">PLU: {p.plu} · {p.qty ?? 0} {p.unit || 'ks'}</span>
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  )
}
