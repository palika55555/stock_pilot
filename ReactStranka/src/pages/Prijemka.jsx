import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuthHeaders } from '../utils/auth'
import './Prijemka.css'

// ─── Helpers ─────────────────────────────────────────────────────────────────

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('sk-SK', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

function fmtNum(v, dec = 2) {
  return new Intl.NumberFormat('sk-SK', {
    minimumFractionDigits: dec,
    maximumFractionDigits: dec,
  }).format(Number(v) || 0)
}

function fmtEur(v) {
  return new Intl.NumberFormat('sk-SK', { style: 'currency', currency: 'EUR' }).format(Number(v) || 0)
}

function statusInfo(status) {
  const map = {
    vysporiadana: { label: 'Vysporiadaná', cls: 'prij-pill--green' },
    otvorena:     { label: 'Otvorená',     cls: 'prij-pill--blue'  },
    storno:       { label: 'Stornovaná',   cls: 'prij-pill--red'   },
    approved:     { label: 'Schválená',    cls: 'prij-pill--green' },
    pending:      { label: 'Čaká na schválenie', cls: 'prij-pill--amber' },
    draft:        { label: 'Koncept',      cls: 'prij-pill--gray'  },
    rejected:     { label: 'Zamietnutá',   cls: 'prij-pill--red'   },
  }
  return map[status] ?? { label: status ?? 'Koncept', cls: 'prij-pill--gray' }
}

// ─── Core component ───────────────────────────────────────────────────────────

/**
 * @param {PrijemkaProps} props
 *
 * PrijemkaProps:
 *   docNumber  : string
 *   date       : string
 *   status     : 'vysporiadana' | 'otvorena' | 'storno' | …
 *   vatIncluded: boolean
 *   vatRate    : number   (default rate for display chip)
 *   supplier   : { name, ico, dic, address }
 *   recipient  : { name, issuedBy }
 *   items      : { name, plu, qty, unit, priceExVat, vatRate, totalIncVat }[]
 *   vatRecap   : { rate, base, vat, total }[]
 *   approvedBy?: string
 *   approvedAt?: string
 */
function PrijemkaDoc({
  docNumber,
  date,
  status = 'vysporiadana',
  vatIncluded = true,
  vatRate = 20,
  supplier = {},
  recipient = {},
  items = [],
  vatRecap = [],
  approvedBy,
  approvedAt,
  createdBy,
}) {
  const statusMeta = statusInfo(status)
  const grandTotal = vatRecap.reduce((s, r) => s + Number(r.total), 0)

  return (
    <div className="prij-doc">

      {/* ── 1. HEADER ─────────────────────────────────────────────── */}
      <header className="prij-header">
        {/* Logo placeholder */}
        <div className="prij-logo-box" aria-label="Logo spoločnosti" />

        {/* Title block */}
        <div className="prij-title-block">
          <h1 className="prij-title">Príjemka tovaru</h1>
          <p className="prij-subtitle">Skladový doklad — príjem na sklad</p>
        </div>

        {/* Meta block */}
        <div className="prij-header-meta">
          <div className="prij-doc-number">{docNumber}</div>
          <div className="prij-header-date">{date}</div>
        </div>
      </header>

      {/* ── 2. STATUS BAR ─────────────────────────────────────────── */}
      <div className="prij-status-bar">
        <div className="prij-status-left">
          <span className={`prij-pill ${statusMeta.cls}`}>{statusMeta.label}</span>
        </div>
        <div className="prij-status-sep" />
        <div className="prij-status-chips">
          <span className="prij-chip">
            {vatIncluded ? 'Ceny vrátane DPH' : 'Ceny bez DPH'}
          </span>
          <span className="prij-chip">
            DPH <strong>{vatRate}&nbsp;%</strong>
          </span>
        </div>
      </div>

      {/* ── 3. PARTIES ────────────────────────────────────────────── */}
      <section className="prij-parties">
        <div className="prij-party">
          <div className="prij-section-label">Dodávateľ</div>
          <div className="prij-party-name">{supplier.name || '—'}</div>
          {(supplier.ico || supplier.dic) && (
            <div className="prij-party-ids">
              {supplier.ico && <span className="prij-party-id">IČO: <span className="prij-mono">{supplier.ico}</span></span>}
              {supplier.dic && <span className="prij-party-id">DIČ: <span className="prij-mono">{supplier.dic}</span></span>}
            </div>
          )}
          {supplier.address && <div className="prij-party-address">{supplier.address}</div>}
        </div>

        <div className="prij-party-divider" />

        <div className="prij-party prij-party--right">
          <div className="prij-section-label">Príjemca / Sklad</div>
          <div className="prij-party-name">{recipient.name || '—'}</div>
          {recipient.issuedBy && (
            <div className="prij-party-meta">
              <span className="prij-label-tiny">Vystavil</span>
              <span>{recipient.issuedBy}</span>
            </div>
          )}
        </div>
      </section>

      {/* ── 4. ITEMS TABLE ────────────────────────────────────────── */}
      <section className="prij-table-section">
        <div className="prij-section-header">
          <span className="prij-section-title">Položky</span>
        </div>
        <div className="prij-table-wrap">
          <table className="prij-table">
            <thead>
              <tr>
                <th className="prij-th prij-th--name">Názov</th>
                <th className="prij-th prij-th--plu">PLU</th>
                <th className="prij-th prij-th--qty">Množstvo</th>
                <th className="prij-th prij-th--unit">MJ</th>
                <th className="prij-th prij-th--price">Cena bez DPH/MJ</th>
                <th className="prij-th prij-th--vat">DPH</th>
                <th className="prij-th prij-th--total">Celkom s DPH</th>
              </tr>
            </thead>
            <tbody>
              {items.length === 0 ? (
                <tr>
                  <td className="prij-td prij-td--empty" colSpan={7}>Žiadne položky</td>
                </tr>
              ) : items.map((item, i) => (
                <tr key={i} className="prij-tr">
                  <td className="prij-td prij-td--name">{item.name}</td>
                  <td className="prij-td prij-td--plu">
                    <span className="prij-mono prij-plu">{item.plu || '—'}</span>
                  </td>
                  <td className="prij-td prij-td--qty prij-mono">
                    {fmtNum(item.qty, 3)}
                  </td>
                  <td className="prij-td prij-td--unit prij-muted">{item.unit}</td>
                  <td className="prij-td prij-td--price prij-mono">
                    {fmtEur(item.priceExVat)}
                  </td>
                  <td className="prij-td prij-td--vat">
                    <span className="prij-pill prij-pill--amber prij-pill--sm">{item.vatRate}&nbsp;%</span>
                  </td>
                  <td className="prij-td prij-td--total prij-mono prij-bold">
                    {fmtEur(item.totalIncVat)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* ── 5. BOTTOM ROW: VAT recap + Grand total ────────────────── */}
      <section className="prij-bottom-row">
        {/* VAT recapitulation */}
        <div className="prij-vat-recap">
          <div className="prij-section-label" style={{ marginBottom: 12 }}>Rekapitulácia DPH</div>
          <table className="prij-vat-table">
            <thead>
              <tr>
                <th className="prij-vth">Sadzba</th>
                <th className="prij-vth prij-vth--right">Základ</th>
                <th className="prij-vth prij-vth--right">DPH</th>
                <th className="prij-vth prij-vth--right">Spolu</th>
              </tr>
            </thead>
            <tbody>
              {vatRecap.map((r, i) => (
                <tr key={i}>
                  <td className="prij-vtd">
                    <span className="prij-pill prij-pill--amber prij-pill--sm">{r.rate}&nbsp;%</span>
                  </td>
                  <td className="prij-vtd prij-vtd--right prij-mono">{fmtEur(r.base)}</td>
                  <td className="prij-vtd prij-vtd--right prij-mono prij-muted">{fmtEur(r.vat)}</td>
                  <td className="prij-vtd prij-vtd--right prij-mono prij-bold">{fmtEur(r.total)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Grand total */}
        <div className="prij-grand-box">
          <div className="prij-grand-label">Celkom na úhradu</div>
          <div className="prij-grand-amount">{fmtEur(grandTotal)}</div>
          <div className="prij-grand-note">vrátane DPH</div>
        </div>
      </section>

      {/* ── 6. FOOTER — signatures ────────────────────────────────── */}
      <footer className="prij-footer">
        {/* Vystavil */}
        <div className="prij-sig-col">
          <div className="prij-sig-line" />
          <div className="prij-sig-role">Vystavil</div>
          {createdBy && <div className="prij-sig-name">{createdBy}</div>}
          <div className="prij-sig-date">{date}</div>
        </div>

        <div className="prij-footer-divider" />

        {/* Schválil */}
        <div className="prij-sig-col">
          <div className="prij-sig-line" />
          <div className="prij-sig-role">Schválil</div>
          <div className="prij-sig-name">{approvedBy || <span className="prij-placeholder">Meno a priezvisko</span>}</div>
          <div className="prij-sig-date">{approvedAt ? fmtDate(approvedAt) : <span className="prij-placeholder">Dátum</span>}</div>
        </div>

        <div className="prij-footer-divider" />

        {/* Pečiatka */}
        <div className="prij-sig-col prij-sig-col--stamp">
          <div className="prij-stamp-box" />
          <div className="prij-sig-role">Pečiatka</div>
        </div>
      </footer>

    </div>
  )
}

// ─── Page wrapper (fetches data or uses demo) ────────────────────────────────

export default function Prijemka() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    if (!id) {
      setData(buildProps(MOCK_RECEIPT, MOCK_ITEMS))
      setLoading(false)
      return
    }
    ;(async () => {
      try {
        const headers = getAuthHeaders()
        const [rRes, iRes] = await Promise.all([
          fetch(`${API_BASE_FOR_CALLS}/inbound-receipts/${id}`, { headers }),
          fetch(`${API_BASE_FOR_CALLS}/inbound-receipts/${id}/items`, { headers }),
        ])
        if (!rRes.ok) throw new Error(`Príjemka nenájdená (${rRes.status})`)
        const [r, i] = await Promise.all([rRes.json(), iRes.json()])
        const items = Array.isArray(i) ? i : (i.items ?? [])
        setData(buildProps(r, items))
      } catch (e) {
        setError(e.message)
      } finally {
        setLoading(false)
      }
    })()
  }, [id])

  if (loading) return <PrijemkaSkeleton />
  if (error)
    return (
      <div className="prij-error-wrap">
        <div className="prij-error-box">
          <div className="prij-error-icon">⚠</div>
          <p>{error}</p>
          <button className="prij-btn" onClick={() => navigate(-1)}>← Späť</button>
        </div>
      </div>
    )

  return (
    <div className="prij-page">
      {/* Toolbar — screen only */}
      <div className="prij-toolbar no-print">
        <button className="prij-btn prij-btn--ghost" onClick={() => navigate(-1)}>← Späť</button>
        <button className="prij-btn prij-btn--dark" onClick={() => window.print()}>🖨 Tlačiť</button>
      </div>

      <PrijemkaDoc {...data} />
    </div>
  )
}

// ─── Map API/DB receipt to PrijemkaProps ─────────────────────────────────────

function buildProps(receipt, rawItems) {
  // Detect default VAT from first item
  const defaultVat = rawItems[0]?.vat_rate ?? rawItems[0]?.vat_percent ?? 20

  // VAT recap
  const groups = {}
  for (const it of rawItems) {
    const rate = Number(it.vat_rate ?? it.vat_percent ?? 20)
    if (!groups[rate]) groups[rate] = { rate, base: 0, vat: 0, total: 0 }
    const base = Number(it.unit_price ?? 0) * Number(it.quantity ?? 0)
    const vat = base * (rate / 100)
    groups[rate].base += base
    groups[rate].vat += vat
    groups[rate].total += base + vat
  }
  const vatRecap = Object.values(groups).sort((a, b) => a.rate - b.rate)

  return {
    docNumber: receipt.receipt_number ?? `PR-${receipt.id}`,
    date: fmtDate(receipt.receipt_date ?? receipt.created_at),
    status: receipt.status ?? 'vysporiadana',
    vatIncluded: false,
    vatRate: defaultVat,
    supplier: {
      name:    receipt.supplier_name    ?? '—',
      ico:     receipt.supplier_ico     ?? '',
      dic:     receipt.supplier_dic     ?? '',
      address: receipt.supplier_address ?? '',
    },
    recipient: {
      name:     receipt.warehouse_name ?? receipt.recipient_name ?? '—',
      issuedBy: receipt.created_by ?? receipt.user_id ?? '',
    },
    items: rawItems.map((it) => {
      const priceExVat = Number(it.unit_price ?? 0)
      const qty        = Number(it.quantity ?? 0)
      const rate       = Number(it.vat_rate ?? it.vat_percent ?? 20)
      const base       = priceExVat * qty
      return {
        name:        it.product_name ?? it.name ?? '—',
        plu:         it.sku ?? it.plu ?? '',
        qty,
        unit:        it.unit ?? 'ks',
        priceExVat,
        vatRate:     rate,
        totalIncVat: base * (1 + rate / 100),
      }
    }),
    vatRecap,
    createdBy:  receipt.created_by ?? receipt.user_id ?? '',
    approvedBy: receipt.approver_username ?? '',
    approvedAt: receipt.approved_at ?? '',
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

function Sk({ w = '100%', h = 16, mb = 0 }) {
  return <span className="prij-skel" style={{ width: w, height: h, marginBottom: mb, display: 'block' }} />
}

function PrijemkaSkeleton() {
  return (
    <div className="prij-page">
      <div className="prij-toolbar no-print" style={{ justifyContent: 'space-between' }}>
        <Sk w={80} h={32} />
        <Sk w={100} h={32} />
      </div>
      <div className="prij-doc">
        <div className="prij-header">
          <div className="prij-logo-box" />
          <div className="prij-title-block">
            <Sk w={220} h={28} mb={8} />
            <Sk w={160} h={14} />
          </div>
          <div className="prij-header-meta">
            <Sk w={140} h={20} mb={6} />
            <Sk w={80} h={14} />
          </div>
        </div>
        <div className="prij-status-bar">
          <Sk w={110} h={26} />
        </div>
        <div className="prij-parties">
          <div className="prij-party" style={{ flex: 1 }}>
            <Sk w={60} h={10} mb={10} />
            <Sk w={180} h={20} mb={8} />
            <Sk w={220} h={14} mb={4} />
            <Sk w={160} h={14} />
          </div>
          <div className="prij-party-divider" />
          <div className="prij-party prij-party--right" style={{ flex: 1 }}>
            <Sk w={60} h={10} mb={10} />
            <Sk w={160} h={20} mb={8} />
            <Sk w={120} h={14} />
          </div>
        </div>
        <Sk h={200} mb={0} />
      </div>
    </div>
  )
}

// ─── Mock data ────────────────────────────────────────────────────────────────

const MOCK_RECEIPT = {
  id: 42,
  receipt_number: 'PR-2026-0042',
  status: 'vysporiadana',
  receipt_date: '2026-03-17T10:30:00Z',
  warehouse_name: 'Hlavný sklad – BA',
  invoice_number: 'FAC-2026-1234',
  delivery_note_number: 'DN-9988',
  po_number: 'PO-2026-055',
  created_by: 'Ján Novák',
  approver_username: 'Mária Horáčková',
  approved_at: '2026-03-17T14:00:00Z',
  supplier_name: 'ABC Distribúcia s.r.o.',
  supplier_ico: '12345678',
  supplier_dic: 'SK2012345678',
  supplier_address: 'Priemyselná 12, 821 09 Bratislava',
}

const MOCK_ITEMS = [
  { product_name: 'Minerálna voda 0,5L',       sku: 'MW-05',   quantity: 240, unit: 'ks',  unit_price: 0.35, vat_rate: 20 },
  { product_name: 'Ovocná šťava 1L mix',        sku: 'JS-1L',   quantity: 96,  unit: 'ks',  unit_price: 1.45, vat_rate: 20 },
  { product_name: 'Papierové obrúsky 100ks',    sku: 'PAP-100', quantity: 50,  unit: 'bal', unit_price: 2.20, vat_rate: 20 },
  { product_name: 'Dezinfekčný gél 500ml',      sku: 'DEZ-500', quantity: 30,  unit: 'ks',  unit_price: 4.80, vat_rate: 20 },
]
