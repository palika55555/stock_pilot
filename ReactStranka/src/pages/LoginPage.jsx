import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import '../App.css'
import { API_BASE_FOR_CALLS } from '../config'

export default function LoginPage() {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [totpCode, setTotpCode] = useState('')
  const [backupCode, setBackupCode] = useState('')
  const [step, setStep] = useState('password') // password | verify2fa | setup2fa
  const [challengeToken, setChallengeToken] = useState('')
  const [otpauthUri, setOtpauthUri] = useState('')
  const [setupCode, setSetupCode] = useState('')
  const [showBackup, setShowBackup] = useState(false)
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState({ type: '', text: '' })
  const navigate = useNavigate()

  const handlePasswordSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage({ type: '', text: '' })
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      })
      const data = await res.json().catch(() => ({}))
      if (res.ok && data.success && data.requires2fa) {
        setChallengeToken(data.loginChallengeToken || '')
        setStep('verify2fa')
        setMessage({ type: '', text: '' })
        return
      }
      if (res.ok && data.success && data.requires2faSetup) {
        const setupRes = await fetch(`${API_BASE_FOR_CALLS}/auth/2fa/setup`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ loginChallengeToken: data.loginChallengeToken }),
        })
        const setupData = await setupRes.json().catch(() => ({}))
        if (!setupRes.ok || !setupData.success) {
          setMessage({ type: 'error', text: setupData.error || 'Nepodarilo sa spustiť 2FA nastavenie.' })
          return
        }
        setChallengeToken(data.loginChallengeToken || '')
        setOtpauthUri(setupData.otpauthUri || '')
        setStep('setup2fa')
        return
      }
      if (res.ok && data.success) {
        // Backend returns accessToken, refreshToken, user (not "token")
        const auth = {
          user: data.user || { id: null, fullName: username, username, role: 'user', email: '' },
          token: data.accessToken,
          refreshToken: data.refreshToken ?? null,
        }
        localStorage.setItem('stockpilot_auth', JSON.stringify(auth))
        setMessage({
          type: 'success',
          text: `Vitajte, ${data.user?.fullName || data.user?.username || username}!`,
        })
        navigate('/dashboard', { replace: true })
      } else {
        setMessage({ type: 'error', text: data.error || 'Prihlásenie zlyhalo.' })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'Backend nedostupný. Skontrolujte URL alebo sieť.' })
    } finally {
      setLoading(false)
    }
  }

  const finishAuth = (data) => {
    const auth = {
      user: data.user || { id: null, fullName: username, username, role: 'user', email: '' },
      token: data.accessToken,
      refreshToken: data.refreshToken ?? null,
    }
    localStorage.setItem('stockpilot_auth', JSON.stringify(auth))
    navigate('/dashboard', { replace: true })
  }

  const handleVerifySubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage({ type: '', text: '' })
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/auth/2fa/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          loginChallengeToken: challengeToken,
          totpCode: showBackup ? undefined : totpCode,
          backupCode: showBackup ? backupCode : undefined,
        }),
      })
      const data = await res.json().catch(() => ({}))
      if (res.ok && data.success) {
        finishAuth(data)
      } else {
        setMessage({ type: 'error', text: data.error || 'Overenie 2FA zlyhalo.' })
      }
    } catch {
      setMessage({ type: 'error', text: 'Backend nedostupný. Skontrolujte URL alebo sieť.' })
    } finally {
      setLoading(false)
    }
  }

  const handleSetupConfirm = async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage({ type: '', text: '' })
    try {
      const res = await fetch(`${API_BASE_FOR_CALLS}/auth/2fa/confirm`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ loginChallengeToken: challengeToken, totpCode: setupCode }),
      })
      const data = await res.json().catch(() => ({}))
      if (res.ok && data.success) {
        if (Array.isArray(data.backupCodes) && data.backupCodes.length) {
          setMessage({
            type: 'success',
            text: `2FA aktivované. Záložné kódy: ${data.backupCodes.join(', ')}`,
          })
        }
        finishAuth(data)
      } else {
        setMessage({ type: 'error', text: data.error || 'Aktivácia 2FA zlyhala.' })
      }
    } catch {
      setMessage({ type: 'error', text: 'Backend nedostupný. Skontrolujte URL alebo sieť.' })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="login-page">
      <div className="login-bg">
        <div className="grid-overlay" aria-hidden="true" />
        <div className="glow glow-1" aria-hidden="true" />
        <div className="glow glow-2" aria-hidden="true" />
      </div>

      <main className="login-card">
        <div className="logo-wrap">
          <span className="logo-label">STOCK</span>
          <h1 className="logo-title">PILOT</h1>
          <p className="tagline">Stock management. Under control.</p>
        </div>

        <form className="login-form" onSubmit={step === 'password' ? handlePasswordSubmit : step === 'verify2fa' ? handleVerifySubmit : handleSetupConfirm}>
          {step === 'password' && (
            <>
          <label className="field-label">
            <span>Používateľské meno</span>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="Zadajte používateľské meno"
              autoComplete="username"
              required
              className="input"
            />
          </label>
          <label className="field-label">
            <span>Heslo</span>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              autoComplete="current-password"
              required
              className="input"
            />
          </label>
            </>
          )}
          {step === 'verify2fa' && (
            <>
              <p className="footer-text" style={{ marginBottom: 12 }}>
                Zadajte 6-miestny kód z autentifikátora.
              </p>
              <label className="field-label">
                <span>{showBackup ? 'Záložný kód' : 'TOTP kód'}</span>
                <input
                  type="text"
                  value={showBackup ? backupCode : totpCode}
                  onChange={(e) => (showBackup ? setBackupCode(e.target.value) : setTotpCode(e.target.value))}
                  placeholder={showBackup ? 'XXXX-XXXX' : '123456'}
                  required
                  className="input"
                />
              </label>
              <button type="button" className="dashboard-topbar__logout" onClick={() => setShowBackup((s) => !s)}>
                {showBackup ? 'Použiť TOTP' : 'Použiť záložný kód'}
              </button>
            </>
          )}
          {step === 'setup2fa' && (
            <>
              <p className="footer-text" style={{ marginBottom: 12 }}>
                Naskenujte URL v autentifikátore a potvrďte prvý kód.
              </p>
              <label className="field-label">
                <span>otpauth URL</span>
                <input type="text" value={otpauthUri} readOnly className="input" />
              </label>
              <label className="field-label">
                <span>Potvrdzovací TOTP kód</span>
                <input
                  type="text"
                  value={setupCode}
                  onChange={(e) => setSetupCode(e.target.value)}
                  placeholder="123456"
                  required
                  className="input"
                />
              </label>
            </>
          )}
          {message.text && (
            <p className={message.type === 'success' ? 'msg-success' : 'msg-error'} role="alert">
              {message.text}
            </p>
          )}
          <button type="submit" className="btn-login" disabled={loading}>
            {loading ? (
              <span className="btn-spinner" aria-hidden="true" />
            ) : (
              step === 'password' ? 'Prihlásiť sa' : step === 'verify2fa' ? 'Overiť 2FA' : 'Aktivovať 2FA'
            )}
          </button>
        </form>

        <p className="footer-text">
          Stock Pilot &copy; {new Date().getFullYear()}
        </p>
      </main>
    </div>
  )
}
