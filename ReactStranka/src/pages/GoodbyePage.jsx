import { useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { getAuth, clearAuth } from '../utils/auth'
import './GoodbyePage.css'

export default function GoodbyePage() {
  const navigate = useNavigate()
  const auth = getAuth()
  const name =
    auth?.user?.fullName?.trim() ||
    auth?.user?.username ||
    ''

  useEffect(() => {
    const t = window.setTimeout(() => {
      clearAuth()
      navigate('/', { replace: true })
    }, 2400)
    return () => window.clearTimeout(t)
  }, [navigate])

  return (
    <div className="goodbye-page" role="status" aria-live="polite">
      <div className="goodbye-page__glow" aria-hidden />
      <div className="goodbye-page__grid" aria-hidden />
      <div className="goodbye-page__content">
        <h1 className="goodbye-page__title">Dovidenia</h1>
        {name ? <p className="goodbye-page__name">{name}</p> : null}
        <p className="goodbye-page__subtitle">Ďakujeme za prácu</p>
        <div className="goodbye-page__bar" aria-hidden>
          <div className="goodbye-page__bar-fill" />
        </div>
      </div>
    </div>
  )
}
