import { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { getAuth, getAuthHeaders } from '../utils/auth'
import { apiFetch } from '../utils/apiFetch'
import { API_BASE_FOR_CALLS } from '../config'
import './SystemStatusPage.css'

function fmtUptime(sec) {
  if (!sec) return '—'
  const h = Math.floor(sec / 3600)
  const m = Math.floor((sec % 3600) / 60)
  const s = sec % 60
  return [h && `${h}h`, m && `${m}m`, `${s}s`].filter(Boolean).join(' ')
}

function fmtDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('sk-SK')
}

function fmtNum(n) {
  return new Intl.NumberFormat('sk-SK').format(Number(n) || 0)
}

function StatusDot({ status }) {
  const cls = status === 'ok' ? 'ss-dot ss-dot--ok' : status === 'warn' ? 'ss-dot ss-dot--warn' : 'ss-dot ss-dot--error'
  return <span className={cls} />
}

function Section({ title, children }) {
  return (
    <div className="ss-section">
      <h3 className="ss-section-title">{title}</h3>
      {children}
    </div>
  )
}

function MetaRow({ label, value, accent }) {
  return (
    <div className="ss-meta-row">
      <span className="ss-meta-label">{label}</span>
      <span className={`ss-meta-value${accent ? ' ss-meta-value--accent' : ''}`}>{value}</span>
    </div>
  )
}

export default function SystemStatusPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [lastRefreshed, setLastRefreshed] = useState(null)

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    if (a.user?.role !== 'db_owner') { navigate('/dashboard', { replace: true }); return }
    setAuth(a)
  }, [navigate])

  const load = useCallback(() => {
    if (!auth) return
    setLoading(true)
    fetch(`${API_BASE_FOR_CALLS}/admin/system-status`, { headers: getAuthHeaders(auth) })
      .then((r) => r.ok ? r.json() : Promise.reject(r.status))
      .then((d) => { setData(d); setLastRefreshed(new Date()); setError('') })
      .catch((e) => setError(`Načítanie zlyhalo (${e})`))
      .finally(() => setLoading(false))
  }, [auth])

  useEffect(() => {
    if (auth) load()
  }, [auth, load])

  if (!auth) return null

  const dbOk = data?.server?.poolReady !== false

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main ss-page">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <h2 className="dashboard-overview-title">System Status</h2>
          <button type="button" className="ss-refresh-btn" onClick={load} disabled={loading}>
            {loading ? <span className="btn-spinner" /> : '↻'} Obnoviť
          </button>
        </div>

        {lastRefreshed && (
          <p className="ss-refreshed">Posledná kontrola: {lastRefreshed.toLocaleTimeString('sk-SK')}</p>
        )}

        {error && <p className="customers-error">{error}</p>}

        {loading && !data && (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam stav systému...</span>
          </div>
        )}

        {data && (
          <>
            {/* Server */}
            <Section title="Server">
              <div className="ss-card-row">
                <div className="ss-card">
                  <div className="ss-card-label">Databáza</div>
                  <div className="ss-card-value">
                    <StatusDot status={dbOk ? 'ok' : 'error'} />
                    {dbOk ? 'Pripojená' : 'Nedostupná'}
                  </div>
                </div>
                <div className="ss-card">
                  <div className="ss-card-label">Uptime</div>
                  <div className="ss-card-value">{fmtUptime(data.server?.uptimeSeconds)}</div>
                </div>
                <div className="ss-card">
                  <div className="ss-card-label">Prostredie</div>
                  <div className="ss-card-value">{data.server?.nodeEnv || '—'}</div>
                </div>
              </div>
            </Section>

            {/* Users */}
            <Section title="Používatelia">
              <div className="ss-card-row">
                <div className="ss-card">
                  <div className="ss-card-label">Celkom</div>
                  <div className="ss-card-value ss-card-value--big">{fmtNum(data.users?.total)}</div>
                </div>
                <div className="ss-card">
                  <div className="ss-card-label">Adminov</div>
                  <div className="ss-card-value ss-card-value--big">{fmtNum(data.users?.admins)}</div>
                </div>
                <div className="ss-card">
                  <div className="ss-card-label">Zablokovaných</div>
                  <div className={`ss-card-value ss-card-value--big ${data.users?.blocked > 0 ? 'ss-card-value--warn' : ''}`}>
                    {fmtNum(data.users?.blocked)}
                  </div>
                </div>
              </div>
            </Section>

            {/* Master data */}
            <Section title="Kmeňové dáta">
              <div className="ss-meta-grid">
                {Object.entries(data.masterData || {}).map(([k, v]) => (
                  <MetaRow key={k} label={k.charAt(0).toUpperCase() + k.slice(1)} value={fmtNum(v)} />
                ))}
              </div>
            </Section>

            {/* Transactional data */}
            <Section title="Transakčné dáta (Flutter sync)">
              <div className="ss-table-wrap">
                <table className="ss-table">
                  <thead>
                    <tr>
                      <th>Entita</th>
                      <th>Záznamy</th>
                      <th>Posledná aktivita</th>
                      <th>Stav</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(() => {
                      const td = data.transactionalData || {}
                      const rows = [
                        { label: 'Príjemky', count: td.receipts?.headers, sub: `${fmtNum(td.receipts?.items)} položiek`, last: td.receipts?.lastCreatedAt },
                        { label: 'Výdajky', count: td.stockOuts?.headers, sub: `${fmtNum(td.stockOuts?.items)} položiek`, last: td.stockOuts?.lastCreatedAt },
                        { label: 'Receptúry', count: td.recipes?.total, sub: `${fmtNum(td.recipes?.ingredients)} surovín`, last: null },
                        { label: 'Výrobné príkazy', count: td.productionOrders?.total, sub: null, last: td.productionOrders?.lastCreatedAt },
                        { label: 'Cenové ponuky', count: td.quotes?.headers, sub: `${fmtNum(td.quotes?.items)} položiek`, last: td.quotes?.lastCreatedAt },
                        { label: 'Transporty', count: td.transports, sub: null, last: null },
                        { label: 'Firma', count: td.company, sub: null, last: null },
                      ]
                      return rows.map((row) => (
                        <tr key={row.label}>
                          <td>{row.label}</td>
                          <td>
                            <strong>{fmtNum(row.count)}</strong>
                            {row.sub && <span className="ss-table-sub"> · {row.sub}</span>}
                          </td>
                          <td className="ss-table-muted">{fmtDate(row.last)}</td>
                          <td><StatusDot status={row.count >= 0 ? 'ok' : 'error'} /></td>
                        </tr>
                      ))
                    })()}
                  </tbody>
                </table>
              </div>
            </Section>

            {/* Endpoints */}
            <Section title="API Endpointy">
              <div className="ss-table-wrap">
                <table className="ss-table">
                  <thead>
                    <tr>
                      <th>Skupina</th>
                      <th>Endpoint</th>
                      <th>Metóda</th>
                      <th>Stav</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(data.endpoints || []).map((ep) => (
                      <tr key={ep.path + ep.method}>
                        <td>{ep.group}</td>
                        <td className="ss-table-mono">{ep.path}</td>
                        <td>
                          <span className={`ss-method ss-method--${ep.method.toLowerCase()}`}>{ep.method}</span>
                        </td>
                        <td>
                          <StatusDot status={ep.status} />
                          <span className={`ss-ep-status ss-ep-status--${ep.status}`}>
                            {ep.status === 'ok' ? 'OK' : ep.status === 'warn' ? 'Varovanie' : 'Chyba'}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Section>

            {/* Notifications count */}
            <Section title="Notifikácie v systéme">
              <MetaRow label="Celkový počet notifikácií" value={fmtNum(data.notifications)} />
            </Section>
          </>
        )}
      </main>
    </div>
  )
}
