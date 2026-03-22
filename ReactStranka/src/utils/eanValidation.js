/**
 * Kontrola kontrolného čísla EAN-8 a EAN-13 (GS1).
 * Prázdny reťazec = OK (nepovinné pole).
 */
export function validateEanChecksum(raw) {
  const d = String(raw ?? '').replace(/\D/g, '')
  if (d.length === 0) return { ok: true }
  if (d.length === 13) return validateEan13(d)
  if (d.length === 8) return validateEan8(d)
  return {
    ok: false,
    message: 'EAN má mať 8 alebo 13 číslic (alebo nechajte prázdne).',
  }
}

function validateEan13(code) {
  let sum = 0
  for (let i = 0; i < 12; i++) {
    const n = parseInt(code[i], 10)
    if (Number.isNaN(n)) return { ok: false, message: 'Neplatné znaky v EAN.' }
    sum += n * (i % 2 === 0 ? 1 : 3)
  }
  const check = (10 - (sum % 10)) % 10
  const last = parseInt(code[12], 10)
  if (check !== last) return { ok: false, message: 'EAN-13 má nesprávne kontrolné číslo.' }
  return { ok: true }
}

function validateEan8(code) {
  let sum = 0
  for (let i = 0; i < 7; i++) {
    const n = parseInt(code[i], 10)
    if (Number.isNaN(n)) return { ok: false, message: 'Neplatné znaky v EAN.' }
    sum += n * (i % 2 === 0 ? 3 : 1)
  }
  const check = (10 - (sum % 10)) % 10
  const last = parseInt(code[7], 10)
  if (check !== last) return { ok: false, message: 'EAN-8 má nesprávne kontrolné číslo.' }
  return { ok: true }
}
