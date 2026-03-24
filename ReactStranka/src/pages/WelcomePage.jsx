import { useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { getAuth } from '../utils/auth'
import './WelcomePage.css'

export default function WelcomePage() {
  const navigate = useNavigate()
  const auth = getAuth()
  const name =
    auth?.user?.fullName?.trim() ||
    auth?.user?.username ||
    ''

  useEffect(() => {
    const t = window.setTimeout(() => {
      navigate('/dashboard', { replace: true })
    }, 2400)
    return () => window.clearTimeout(t)
  }, [navigate])

  return (
    <div className="welcome-page" role="status" aria-live="polite">
      <div className="welcome-page__glow" aria-hidden />
      <div className="welcome-page__grid" aria-hidden />
      <div className="welcome-page__content">
        <h1 className="welcome-page__title">Vitajte</h1>
        <p className="welcome-page__name">{name}</p>
        <div className="welcome-page__bar" aria-hidden>
          <div className="welcome-page__bar-fill" />
        </div>
      </div>
    </div>
  )
}
