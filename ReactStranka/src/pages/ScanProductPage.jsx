import { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { Html5Qrcode, Html5QrcodeSupportedFormats } from 'html5-qrcode'
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

  const handleScanAgain = () => {
    setShowResult(false)
    setLastScanned(null)
    if (scannerRef.current && !scannerRef.current.isScanning) {
      scannerRef.current.resume()
    }
    setScanning(true)
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
              Naskenovaný produkt
            </h2>
            <p className="scan-product-result-code">Kód: {lastScanned}</p>
            <div className="scan-product-result-row">
              <span>Na sklade:</span>
              <strong>—</strong>
            </div>
            <p className="scan-product-result-hint">
              Prepojenie so skladom môžete doplniť neskôr.
            </p>
            <div className="scan-product-result-actions">
              <button type="button" className="scan-product-btn-primary" onClick={handleScanAgain}>
                Skenovať ďalej
              </button>
              <button type="button" className="scan-product-btn-secondary" onClick={handleBack}>
                Späť na prehľad
              </button>
            </div>
          </div>
        )}
      </main>
    </div>
  )
}
