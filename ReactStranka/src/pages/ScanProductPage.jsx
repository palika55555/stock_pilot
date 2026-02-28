import { useState, useEffect, useRef, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { Html5Qrcode, Html5QrcodeSupportedFormats } from 'html5-qrcode'
import { API_BASE_FOR_CALLS } from '../config'
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
  const [productResult, setProductResult] = useState(null) // null | 'loading' | 'not_found' | { name, plu, ean, unit, qty }
  const [assignOpen, setAssignOpen] = useState(false)
  const [productsList, setProductsList] = useState([])
  const [assignSearch, setAssignSearch] = useState('')
  const [assignLoading, setAssignLoading] = useState(false)
  const [assignSuccess, setAssignSuccess] = useState(false)
  const scannerRef = useRef(null)
  const containerId = 'scan-product-reader'

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

  const fetchProductByBarcode = useCallback(async (code) => {
    if (!auth?.token) return null
    const res = await fetch(
      `${API_BASE_FOR_CALLS}/products/by-barcode?code=${encodeURIComponent(code)}`,
      { headers: { Authorization: auth.token } }
    )
    if (res.status === 404) return 'not_found'
    if (!res.ok) throw new Error('API chyba')
    return res.json()
  }, [auth?.token])

  useEffect(() => {
    if (!showResult || !lastScanned || !auth?.token) return
    setProductResult('loading')
    let cancelled = false
    fetchProductByBarcode(lastScanned)
      .then((data) => {
        if (!cancelled) setProductResult(data === null ? 'not_found' : data)
      })
      .catch(() => {
        if (!cancelled) setProductResult('not_found')
      })
    return () => { cancelled = true }
  }, [showResult, lastScanned, auth?.token, fetchProductByBarcode])

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
    fetch(url, { headers: { Authorization: auth.token } })
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
    setAssignSuccess(false)
    if (scannerRef.current && !scannerRef.current.isScanning) {
      scannerRef.current.resume()
    }
    setScanning(true)
  }

  const handleAssignToProduct = (product) => {
    if (!auth?.token || !lastScanned) return
    const uniqueId = product.unique_id
    setAssignLoading(true)
    fetch(`${API_BASE_FOR_CALLS}/products/${encodeURIComponent(uniqueId)}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: auth.token,
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
            {productResult && productResult !== 'loading' && productResult !== 'not_found' && (
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
                  <button type="button" className="scan-product-btn-primary" onClick={handleScanAgain}>
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
                    key={p.unique_id}
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
