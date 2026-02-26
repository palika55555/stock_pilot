import { useState } from 'react'
import './App.css'

function App() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = (e) => {
    e.preventDefault()
    setLoading(true)
    // TODO: connect to your auth API
    setTimeout(() => setLoading(false), 800)
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
