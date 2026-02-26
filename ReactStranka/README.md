# Stock Pilot — Web login

React prihlasovacia stránka pre Stock Pilot.

## Spustenie

```bash
npm install
npm run dev
```

Otvor [http://localhost:5173](http://localhost:5173).

## Build

```bash
npm run build
```

Výstup je v priečinku `dist/`.

## Deploy na Vercel

1. Nahraj repozitár (GitHub / GitLab / Bitbucket) do Vercel alebo použij **Vercel CLI**:  
   `npm i -g vercel` a v priečinku `ReactStranka` spusti `vercel`.

2. Ak deployuješ celý repozitár **stock_pilot**, v nastavení projektu na Vercel nastav **Root Directory** na `ReactStranka`.

3. Build a výstup (Vite) sú nastavené v `vercel.json`; ďalšia konfigurácia nie je potrebná. Po pushu sa spustí automatický deploy.
