import { useEffect } from 'react'
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
  useEffect(() => {
    if (!open) return
    const onKey = (e) => { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', onKey)
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', onKey)
      document.body.style.overflow = ''
    }
  }, [open, onClose])

  if (!open) return null

  return (
    <>
      <div className="drawer-overlay" onClick={onClose} aria-hidden="true" />
      <div className="drawer-panel" role="dialog" aria-modal="true" aria-label={title}>
        <div className="drawer-header">
          <h3 className="drawer-title">{title}</h3>
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
