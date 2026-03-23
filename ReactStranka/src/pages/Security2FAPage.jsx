import { useEffect, useState } from 'react'
import { API_BASE_FOR_CALLS } from '../config'
import { getAuth, getAuthHeaders } from '../utils/auth'

export default function Security2FAPage() {
  const [status, setStatus] = useState(null)
  const [code, setCode] = useState('')
  const [password, setPassword] = useState('')
  const [backupCodes, setBackupCodes] = useState([])
  const [msg, setMsg] = useState('')
  const auth = getAuth()

  const loadStatus = async () => {
    const res = await fetch(`${API_BASE_FOR_CALLS}/auth/2fa/status`, { headers: getAuthHeaders(auth) })
    const data = await res.json().catch(() => ({}))
    if (res.ok && data.success) setStatus(data)
  }

  useEffect(() => {
    loadStatus()
  }, [])

  const regenerate = async () => {
    setMsg('')
    const res = await fetch(`${API_BASE_FOR_CALLS}/auth/2fa/backup-codes/regenerate`, {
      method: 'POST',
      headers: getAuthHeaders(auth),
      body: JSON.stringify({ totpCode: code }),
    })
    const data = await res.json().catch(() => ({}))
    if (res.ok && data.success) {
      setBackupCodes(data.backupCodes || [])
      setMsg('Záložné kódy boli regenerované.')
      setCode('')
    } else {
      setMsg(data.error || 'Regenerácia zlyhala.')
    }
  }

  const disable = async () => {
    setMsg('')
    const res = await fetch(`${API_BASE_FOR_CALLS}/auth/2fa/disable`, {
      method: 'POST',
      headers: getAuthHeaders(auth),
      body: JSON.stringify({ password, totpCode: code }),
    })
    const data = await res.json().catch(() => ({}))
    if (res.ok && data.success) {
      setMsg('2FA bolo vypnuté.')
      setPassword('')
      setCode('')
      setBackupCodes([])
      await loadStatus()
    } else {
      setMsg(data.error || 'Vypnutie 2FA zlyhalo.')
    }
  }

  return (
    <div style={{ maxWidth: 640 }}>
      <h1>Security / 2FA</h1>
      <p>Stav: <strong>{status?.enabled ? 'Aktívne' : 'Neaktívne'}</strong></p>
      {!status?.enabled && <p>2FA aktivujete pri ďalšom prihlásení.</p>}
      {status?.enabled && (
        <>
          <label style={{ display: 'block', marginBottom: 8 }}>
            TOTP kód
            <input value={code} onChange={(e) => setCode(e.target.value)} style={{ display: 'block', width: '100%' }} />
          </label>
          <button type="button" onClick={regenerate}>Regenerovať backup kódy</button>
          <div style={{ marginTop: 12 }}>
            <label style={{ display: 'block', marginBottom: 8 }}>
              Heslo (na vypnutie 2FA)
              <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} style={{ display: 'block', width: '100%' }} />
            </label>
            <button type="button" onClick={disable}>Vypnúť 2FA</button>
          </div>
        </>
      )}
      {backupCodes.length > 0 && (
        <div style={{ marginTop: 16 }}>
          <strong>Nové backup kódy:</strong>
          <pre>{backupCodes.join('\n')}</pre>
        </div>
      )}
      {msg && <p>{msg}</p>}
    </div>
  )
}
