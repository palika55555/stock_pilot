import { useState } from 'react'
import './App.css'

const API_BASE = import.meta.env.VITE_API_URL || 'https://backend.stockpilot.sk'

function App() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState({ type: '', text: '' })

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage({ type: '', text: '' })
    try {
      const res = await fetch(`${API_BASE}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      })
      const data = await res.json().catch(() => ({}))
      if (res.ok && data.success) {
        setMessage({ type: 'success', text: `Vitajte, ${data.user?.email || email}!` })
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
            <span>E-mail</span>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="vas@email.sk"
              autoComplete="email"
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

export default App
