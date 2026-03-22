import { useEffect, useRef } from 'react'
import './DetailDrawer.css'

/**
 * Generic slide-in drawer panel.
 * Props:
 *   open         – boolean
 *   onClose      – () => void
 *   title        – string
 *   mode         – 'view' | 'edit' | 'create'
 *   onEdit       – () => void   (shown in view mode)
 *   onSave       – () => void   (shown in edit/create mode)
 *   onCancel     – () => void   (shown in edit/create mode)
 *   saving       – boolean
 *   children     – drawer body content
 */
export default function DetailDrawer({
  open,
  onClose,
  title,
  mode = 'view',
  onEdit,
  onSave,
  onCancel,
  saving = false,
  children,
}) {
  const panelRef = useRef(null)
  const previouslyFocusedRef = useRef(null)

  useEffect(() => {
    if (!open) return
    const onKey = (e) => { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', onKey)
    document.body.style.overflow = 'hidden'
    previouslyFocusedRef.current = document.activeElement
    requestAnimationFrame(() => {
      const panel = panelRef.current
      if (!panel) return
      const closeBtn = panel.querySelector('.drawer-close')
      if (closeBtn && typeof closeBtn.focus === 'function') closeBtn.focus()
    })
    return () => {
      document.removeEventListener('keydown', onKey)
      document.body.style.overflow = ''
      const prev = previouslyFocusedRef.current
      if (prev && typeof prev.focus === 'function') {
        try { prev.focus() } catch (_) {}
      }
    }
  }, [open, onClose])

  if (!open) return null

  return (
    <>
      <div className="drawer-overlay" onClick={onClose} aria-hidden="true" />
      <div
        ref={panelRef}
        className="drawer-panel"
        role="dialog"
        aria-modal="true"
        aria-labelledby="drawer-panel-title"
      >
        <div className="drawer-header">
          <h3 id="drawer-panel-title" className="drawer-title">{title}</h3>
          <div className="drawer-header-actions">
            {mode === 'view' && onEdit && (
              <button type="button" className="drawer-btn drawer-btn--edit" onClick={onEdit}>
                Upraviť
              </button>
            )}
            {(mode === 'edit' || mode === 'create') && (
              <>
                <button type="button" className="drawer-btn drawer-btn--cancel" onClick={onCancel}>
                  Zrušiť
                </button>
                <button type="button" className="drawer-btn drawer-btn--save" onClick={onSave} disabled={saving}>
                  {saving ? 'Ukladám…' : 'Uložiť'}
                </button>
              </>
            )}
            <button type="button" className="drawer-close" onClick={onClose} aria-label="Zavrieť">✕</button>
          </div>
        </div>
        <div className="drawer-body">{children}</div>
      </div>
    </>
  )
}

/** Reusable detail row for view mode */
export function DrawerRow({ label, value, children }) {
  const content = children ?? value
  if (content == null || content === '') return null
  return (
    <div className="drawer-row">
      <dt className="drawer-label">{label}</dt>
      <dd className="drawer-value">{content}</dd>
    </div>
  )
}
