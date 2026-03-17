import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import './DashboardPage.css'
import './CustomersPage.css'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'

export default function UsersPage() {
  const navigate = useNavigate()
  const [auth, setAuth] = useState(null)
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [actionLoading, setActionLoading] = useState(null)

  useEffect(() => {
    const a = getAuth()
    if (!a?.token) {
      navigate('/', { replace: true })
      return
    }
    if (a.user?.role !== 'admin') {
      navigate('/dashboard', { replace: true })
      return
    }
    setAuth(a)
  }, [navigate])

  const fetchUsers = async () => {
    if (!auth) return
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users`, {
        headers: getAuthHeaders(auth),
      })
      if (res.status === 403) {
        setError('Nemáte oprávnenie.')
        return
      }
      if (!res.ok) throw new Error('Načítanie zlyhalo')
      const data = await res.json()
      setUsers(Array.isArray(data) ? data : [])
    } catch (e) {
      setError(e.message || 'Chyba')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (!auth) return
    fetchUsers()
  }, [auth])

  const doBlock = async (id, block) => {
    setActionLoading(id)
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users/${id}/block`, {
        method: 'PATCH',
        headers: getAuthHeaders(auth),
        body: JSON.stringify({ block }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Akcia zlyhala')
      await fetchUsers()
    } catch (e) {
      alert(e.message || 'Chyba')
    } finally {
      setActionLoading(null)
    }
  }

  const doDeleteUser = async (id, username) => {
    if (!window.confirm(`Naozaj chcete vymazať používateľa "${username}"? Tým sa vymaže celý účet a všetky jeho dáta.`)) return
    setActionLoading(id)
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users/${id}`, {
        method: 'DELETE',
        headers: getAuthHeaders(auth),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Akcia zlyhala')
      await fetchUsers()
    } catch (e) {
      alert(e.message || 'Chyba')
    } finally {
      setActionLoading(null)
    }
  }

  const doDeleteData = async (id, username) => {
    if (!window.confirm(`Naozaj chcete vymazať všetky dáta používateľa "${username}"? (Zákazníci, produkty, ponuky, výroba atď. Účet zostane.)`)) return
    setActionLoading(id)
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/admin/users/${id}/delete-data`, {
        method: 'POST',
        headers: getAuthHeaders(auth),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Akcia zlyhala')
      await fetchUsers()
    } catch (e) {
      alert(e.message || 'Chyba')
    } finally {
      setActionLoading(null)
    }
  }

  if (!auth) return null

  return (
    <div className="dashboard-page-content">
      <main className="dashboard-main customers-main">
        <div className="dashboard-content-header">
          <button type="button" className="dashboard-back" onClick={() => navigate('/dashboard')} title="Späť na prehľad">← Späť</button>
          <h2 className="dashboard-overview-title">Správa používateľov</h2>
        </div>
        <p className="customers-empty" style={{ marginBottom: '1rem' }}>
          Zablokovaný používateľ sa nemôže prihlásiť (web ani aplikácia). Vymazaním účtu sa odstránia aj všetky jeho dáta. „Vymazať dáta“ zmaže zákazníkov, produkty, ponuky atď., účet zostane.
        </p>

        {loading ? (
          <div className="dashboard-loading">
            <span className="btn-spinner" aria-hidden="true" />
            <span>Načítavam používateľov...</span>
          </div>
        ) : error ? (
          <p className="customers-error">{error}</p>
        ) : users.length === 0 ? (
          <p className="customers-empty">Žiadni používatelia.</p>
        ) : (
          <div className="users-table-wrap">
            <table className="users-table">
              <thead>
                <tr>
                  <th>Login</th>
                  <th>Meno</th>
                  <th>Rola</th>
                  <th>Email</th>
                  <th>Stav</th>
                  <th>Akcie</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id}>
                    <td><strong>{u.username}</strong></td>
                    <td>{u.full_name || '—'}</td>
                    <td>{u.role || 'user'}</td>
                    <td>{u.email || '—'}</td>
                    <td>
                      {u.is_blocked ? (
                        <span className="users-badge users-badge--blocked">Zablokovaný</span>
                      ) : (
                        <span className="users-badge users-badge--ok">Aktívny</span>
                      )}
                    </td>
                    <td className="users-actions">
                      {actionLoading === u.id ? (
                        <span className="btn-spinner" style={{ marginRight: '0.5rem' }} aria-hidden="true" />
                      ) : (
                        <>
                          <button
                            type="button"
                            className="users-btn users-btn--block"
                            onClick={() => doBlock(u.id, !u.is_blocked)}
                            title={u.is_blocked ? 'Odblokovať' : 'Zablokovať'}
                          >
                            {u.is_blocked ? 'Odblokovať' : 'Zablokovať'}
                          </button>
                          <button
                            type="button"
                            className="users-btn users-btn--data"
                            onClick={() => doDeleteData(u.id, u.username)}
                            title="Vymazať všetky dáta používateľa (účet zostane)"
                          >
                            Vymazať dáta
                          </button>
                          <button
                            type="button"
                            className="users-btn users-btn--danger"
                            onClick={() => doDeleteUser(u.id, u.username)}
                            disabled={u.id === auth.user?.id}
                            title={u.id === auth.user?.id ? 'Nemôžete vymazať vlastný účet' : 'Vymazať účet a všetky dáta'}
                          >
                            Vymazať účet
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
      </main>
    </div>
  )
}
