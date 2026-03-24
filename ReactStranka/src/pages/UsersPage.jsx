import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import './CustomersPage.css'
import './UsersPage.css'
import { getAuth, getAuthHeaders } from '../utils/auth'
import { apiFetch } from '../utils/apiFetch'
import { API_BASE_FOR_CALLS } from '../config'

const TIER_LABELS = { free: 'Free', basic: 'Basic', pro: 'Pro', enterprise: 'Enterprise' }
const TIER_LIMITS = { free: 0, basic: 2, pro: 5, enterprise: -1 }
const TIER_ORDER = ['free', 'basic', 'pro', 'enterprise']

// ─── DB_OWNER pohľad: správa adminov ─────────────────────────────────────────
function DbOwnerView({ auth }) {
  const [admins, setAdmins] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [actionLoading, setActionLoading] = useState(null)

  const fetchAdmins = async () => {
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users`, { headers: getAuthHeaders(auth) })
      if (!res.ok) throw new Error('Načítanie zlyhalo')
      setAdmins(await res.json())
    } catch (e) { setError(e.message) }
    finally { setLoading(false) }
  }

  useEffect(() => { fetchAdmins() }, [])

  const doWebAccess = async (id, allow) => {
    setActionLoading(`web-${id}`)
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users/${id}/web-access`, {
        method: 'PATCH', headers: getAuthHeaders(auth), body: JSON.stringify({ allow }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Chyba')
      await fetchAdmins()
    } catch (e) { alert(e.message) }
    finally { setActionLoading(null) }
  }

  const doTier = async (id, tier) => {
    setActionLoading(`tier-${id}`)
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users/${id}/tier`, {
        method: 'PATCH', headers: getAuthHeaders(auth), body: JSON.stringify({ tier }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Chyba')
      await fetchAdmins()
    } catch (e) { alert(e.message) }
    finally { setActionLoading(null) }
  }

  const doValidUntil = async (id, validUntil) => {
    setActionLoading(`valid-${id}`)
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users/${id}/tier`, {
        method: 'PATCH', headers: getAuthHeaders(auth), body: JSON.stringify({ valid_until: validUntil === '' ? null : validUntil }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Chyba')
      await fetchAdmins()
    } catch (e) { alert(e.message) }
    finally { setActionLoading(null) }
  }

  const doDelete = async (id, username) => {
    if (!window.confirm(`Vymazať admina "${username}" a všetky jeho dáta?`)) return
    setActionLoading(`del-${id}`)
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users/${id}`, {
        method: 'DELETE', headers: getAuthHeaders(auth),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Chyba')
      await fetchAdmins()
    } catch (e) { alert(e.message) }
    finally { setActionLoading(null) }
  }

  if (loading) return <div className="dashboard-loading"><span className="btn-spinner" /><span>Načítavam...</span></div>
  if (error) return <p className="customers-error">{error}</p>

  return (
    <div className="users-section">
      <p className="users-info-text">
        Spravuj prístupy adminov na web a ich tier (počet sub-userov). Web prístup admina ovplyvňuje aj jeho sub-userov.
      </p>
      {admins.length === 0 ? (
        <p className="customers-empty">Žiadni admini.</p>
      ) : (
        <div className="users-table-wrap">
          <table className="users-table">
            <thead>
              <tr>
                <th>Login</th>
                <th>Meno</th>
                <th>Email</th>
                <th>Web prístup</th>
                <th>Tier</th>
                <th>Platnosť do</th>
                <th>Sub-users</th>
                <th>Registrovaný</th>
                <th>Akcie</th>
              </tr>
            </thead>
            <tbody>
              {admins.map((a) => (
                <tr key={a.id}>
                  <td><strong>{a.username}</strong></td>
                  <td>{a.full_name || '—'}</td>
                  <td>{a.email || '—'}</td>
                  <td>
                    {a.web_access
                      ? <span className="users-badge users-badge--ok">Povolený</span>
                      : <span className="users-badge users-badge--blocked">Zakázaný</span>}
                  </td>
                  <td>
                    <span className={`users-tier-badge users-tier-badge--${a.tier || 'free'}`}>
                      {TIER_LABELS[a.tier] || 'Free'}
                    </span>
                  </td>
                  <td className="users-valid-until-cell">
                    {actionLoading === `valid-${a.id}` ? (
                      <span className="btn-spinner" />
                    ) : (
                      <>
                        <input
                          type="date"
                          className="users-valid-until-input"
                          value={a.tier_valid_until || ''}
                          onChange={(e) => doValidUntil(a.id, e.target.value)}
                          title="Platnosť tiera – prázdne = neobmedzené"
                        />
                        {a.tier_valid_until && (
                          <button type="button" className="users-btn users-btn--small" onClick={() => doValidUntil(a.id, null)} title="Nastaviť neobmedzene">
                            Neobmedz.
                          </button>
                        )}
                      </>
                    )}
                  </td>
                  <td className="users-center">
                    {a.sub_user_count} / {TIER_LIMITS[a.tier] === -1 ? '∞' : TIER_LIMITS[a.tier]}
                  </td>
                  <td>{a.join_date ? new Date(a.join_date).toLocaleDateString('sk') : '—'}</td>
                  <td className="users-actions">
                    {(actionLoading === `web-${a.id}` || actionLoading === `tier-${a.id}` || actionLoading === `del-${a.id}`) ? (
                      <span className="btn-spinner" />
                    ) : (
                      <>
                        <button type="button" className="users-btn users-btn--web"
                          onClick={() => doWebAccess(a.id, !a.web_access)}>
                          {a.web_access ? 'Odbrať web' : 'Povoliť web'}
                        </button>
                        <select className="users-tier-select"
                          value={a.tier || 'free'}
                          onChange={(e) => doTier(a.id, e.target.value)}>
                          {TIER_ORDER.map((t) => (
                            <option key={t} value={t}>{TIER_LABELS[t]}</option>
                          ))}
                        </select>
                        <button type="button" className="users-btn users-btn--danger"
                          onClick={() => doDelete(a.id, a.username)}>
                          Vymazať
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

// ─── ADMIN pohľad: správa vlastných sub-userov ────────────────────────────────
function AdminView({ auth }) {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [actionLoading, setActionLoading] = useState(null)
  const [showAdd, setShowAdd] = useState(false)
  const [form, setForm] = useState({ username: '', password: '', full_name: '', email: '' })
  const [formError, setFormError] = useState('')
  const [formLoading, setFormLoading] = useState(false)

  const fetchData = async () => {
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users`, { headers: getAuthHeaders(auth) })
      if (!res.ok) throw new Error('Načítanie zlyhalo')
      setData(await res.json())
    } catch (e) { setError(e.message) }
    finally { setLoading(false) }
  }

  useEffect(() => { fetchData() }, [])

  const doWebAccess = async (id, allow) => {
    setActionLoading(`web-${id}`)
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users/${id}/web-access`, {
        method: 'PATCH', headers: getAuthHeaders(auth), body: JSON.stringify({ allow }),
      })
      const d = await res.json()
      if (!res.ok) throw new Error(d.error || 'Chyba')
      await fetchData()
    } catch (e) { alert(e.message) }
    finally { setActionLoading(null) }
  }

  const doBlock = async (id, block) => {
    setActionLoading(`block-${id}`)
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users/${id}/block`, {
        method: 'PATCH', headers: getAuthHeaders(auth), body: JSON.stringify({ block }),
      })
      const d = await res.json()
      if (!res.ok) throw new Error(d.error || 'Chyba')
      await fetchData()
    } catch (e) { alert(e.message) }
    finally { setActionLoading(null) }
  }

  const doDelete = async (id, username) => {
    if (!window.confirm(`Vymazať sub-usera "${username}"?`)) return
    setActionLoading(`del-${id}`)
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users/${id}`, {
        method: 'DELETE', headers: getAuthHeaders(auth),
      })
      const d = await res.json()
      if (!res.ok) throw new Error(d.error || 'Chyba')
      await fetchData()
    } catch (e) { alert(e.message) }
    finally { setActionLoading(null) }
  }

  const doAddUser = async (e) => {
    e.preventDefault()
    setFormError('')
    setFormLoading(true)
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/subusers`, {
        method: 'POST', headers: getAuthHeaders(auth), body: JSON.stringify(form),
      })
      const d = await res.json()
      if (!res.ok) throw new Error(d.error || 'Chyba')
      setForm({ username: '', password: '', full_name: '', email: '' })
      setShowAdd(false)
      await fetchData()
    } catch (e) { setFormError(e.message) }
    finally { setFormLoading(false) }
  }

  if (loading) return <div className="dashboard-loading"><span className="btn-spinner" /><span>Načítavam...</span></div>
  if (error) return <p className="customers-error">{error}</p>
  if (!data) return null

  const { tier, web_access, tier_limit, sub_users } = data
  const canAdd = web_access && (tier_limit === -1 || sub_users.length < tier_limit)

  return (
    <div className="users-section">
      {/* Tier info banner */}
      <div className="users-tier-banner">
        <div className="users-tier-banner__left">
          <span className={`users-tier-badge users-tier-badge--${tier}`}>{TIER_LABELS[tier] || tier}</span>
          <span className="users-tier-banner__slots">
            {tier_limit === -1
              ? `${sub_users.length} sub-userov (neobmedzene)`
              : `${sub_users.length} / ${tier_limit} sub-userov`}
          </span>
        </div>
        {!web_access && (
          <span className="users-tier-banner__warn">Nemáte web prístup – kontaktujte administrátora.</span>
        )}
        {canAdd && (
          <button type="button" className="users-btn users-btn--add" onClick={() => setShowAdd((s) => !s)}>
            {showAdd ? '✕ Zavrieť' : '+ Pridať kolegu'}
          </button>
        )}
      </div>

      {/* Formulár pridania sub-usera */}
      {showAdd && (
        <form className="users-add-form" onSubmit={doAddUser}>
          <h3 className="users-add-form__title">Nový kolega / podriadený</h3>
          {formError && <p className="customers-error" style={{ marginBottom: '0.75rem' }}>{formError}</p>}
          <div className="users-add-form__grid">
            <input className="users-add-form__input" placeholder="Prihlasovacie meno *" required
              value={form.username} onChange={(e) => setForm((f) => ({ ...f, username: e.target.value }))} />
            <input className="users-add-form__input" placeholder="Heslo *" type="password" required
              value={form.password} onChange={(e) => setForm((f) => ({ ...f, password: e.target.value }))} />
            <input className="users-add-form__input" placeholder="Celé meno"
              value={form.full_name} onChange={(e) => setForm((f) => ({ ...f, full_name: e.target.value }))} />
            <input className="users-add-form__input" placeholder="Email" type="email"
              value={form.email} onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))} />
          </div>
          <button type="submit" className="users-btn users-btn--add" disabled={formLoading}>
            {formLoading ? <span className="btn-spinner" /> : 'Vytvoriť'}
          </button>
        </form>
      )}

      {sub_users.length === 0 ? (
        <p className="customers-empty" style={{ marginTop: '1.5rem' }}>
          {tier_limit === 0
            ? 'Váš plán (Free) neumožňuje pridávať kolegov. Kontaktujte administrátora pre upgrade.'
            : 'Zatiaľ nemáte žiadnych kolegov. Kliknite "+ Pridať kolegu".'}
        </p>
      ) : (
        <div className="users-table-wrap" style={{ marginTop: '1.5rem' }}>
          <table className="users-table">
            <thead>
              <tr>
                <th>Login</th>
                <th>Meno</th>
                <th>Email</th>
                <th>Stav</th>
                <th>Web prístup</th>
                <th>Akcie</th>
              </tr>
            </thead>
            <tbody>
              {sub_users.map((u) => (
                <tr key={u.id}>
                  <td><strong>{u.username}</strong></td>
                  <td>{u.full_name || '—'}</td>
                  <td>{u.email || '—'}</td>
                  <td>
                    {u.is_blocked
                      ? <span className="users-badge users-badge--blocked">Zablokovaný</span>
                      : <span className="users-badge users-badge--ok">Aktívny</span>}
                  </td>
                  <td>
                    {u.web_access
                      ? <span className="users-badge users-badge--ok">Povolený</span>
                      : <span className="users-badge users-badge--blocked">Zakázaný</span>}
                  </td>
                  <td className="users-actions">
                    {(actionLoading === `web-${u.id}` || actionLoading === `block-${u.id}` || actionLoading === `del-${u.id}`) ? (
                      <span className="btn-spinner" />
                    ) : (
                      <>
                        <button type="button" className="users-btn users-btn--web"
                          onClick={() => doWebAccess(u.id, !u.web_access)}
                          disabled={!web_access}>
                          {u.web_access ? 'Odbrať web' : 'Povoliť web'}
                        </button>
                        <button type="button" className="users-btn users-btn--block"
                          onClick={() => doBlock(u.id, !u.is_blocked)}>
                          {u.is_blocked ? 'Odblokovať' : 'Zablokovať'}
                        </button>
                        <button type="button" className="users-btn users-btn--danger"
                          onClick={() => doDelete(u.id, u.username)}>
                          Vymazať
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

// ─── Hlavná stránka ───────────────────────────────────────────────────────────
export default function UsersPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) { navigate('/', { replace: true }); return }
    if (a.user?.role !== 'admin' && a.user?.role !== 'db_owner') {
      navigate('/dashboard', { replace: true }); return
    }
    setAuth(a)
  }, [navigate])

  if (!auth) return null

  const isDbOwner = auth.user?.role === 'db_owner'

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main customers-main">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')}>← Späť</button>
          <h2 className="dashboard-overview-title">
            {isDbOwner ? 'Správa adminov' : 'Moji kolegovia'}
          </h2>
        </div>
        {isDbOwner
          ? <DbOwnerView auth={auth} />
          : <AdminView auth={auth} />}
      </main>
    </div>
  )
}
