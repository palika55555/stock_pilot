import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import '../App.css'
import { API_BASE_FOR_CALLS } from '../config'

export default function LoginPage() {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState({ type: '', text: '' })
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
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
      if (res.ok && data.success) {
        const auth = {
          token: data.token,
          user: data.user || { fullName: username, username, role: 'user' },
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

        <form className="login-form" onSubmit={handleSubmit}>
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
          {message.text && (
            <p className={message.type === 'success' ? 'msg-success' : 'msg-error'} role="alert">
              {message.text}
            </p>
          )}
          <button type="submit" className="btn-login" disabled={loading}>
            {loading ? (
              <span className="btn-spinner" aria-hidden="true" />
            ) : (
              'Prihlásiť sa'
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
