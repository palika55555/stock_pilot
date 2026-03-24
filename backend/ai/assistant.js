/**
 * AI asistent – odpovede + nástroj navigate (klient vykoná navigáciu).
 * Google Gemini API – kľúč len v prostredí: GEMINI_API_KEY (alebo GOOGLE_API_KEY).
 * GEMINI_MODEL – predvolene gemini-1.5-flash (gemini-2.0-flash často nemá free tier / limit 0).
 * GEMINI_MODEL_FALLBACKS – voliteľné, čiarkou oddelené modely (skúšajú sa pri quota / 429).
 */
const rateLimit = require('express-rate-limit');

const NAVIGATE_SCREENS = [
  'home',
  'search',
  'products',
  'customers',
  'suppliers',
  'production',
  'goods_receipt',
  'stock_out',
  'quotes',
  'reports',
  'settings',
  'warehouses',
  'warehouse_movements',
  'recipes',
  'production_orders',
  'pallets',
  'invoices',
  'inventory_history',
  'transport',
  'scanner',
  'notifications',
];

const SYSTEM_PROMPT = `Si pomocník v aplikácii Stock Pilot (sklad, výroba, doprava, faktúry).
Odpovedaj stručne a po slovensky. Ak používateľ chce prejsť na konkrétnu obrazovku alebo „otvoriť“ niečo z menu, zavolaj nástroj navigate s príslušným screen.
Ak stačí vysvetlenie bez navigácie, odpovedz len textom bez nástroja.
Obrazovky: home (prehľad), search (vyhľadávanie), products (produkty/skladové karty), customers, suppliers, production, goods_receipt (príjemka), stock_out (výdajka), quotes (cenové ponuky), reports, settings, warehouses, warehouse_movements (pohyby skladu), recipes, production_orders, pallets (zákazníci/palety), invoices, inventory_history (história inventúry), transport (doprava/kalkulačka), scanner (skenovanie EAN), notifications (centrum oznámení).`;

function getGeminiKey() {
  return (process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || '').trim();
}

function buildGeminiTools() {
  return [
    {
      functionDeclarations: [
        {
          name: 'navigate',
          description:
            'Otvorí zvolenú obrazovku v aplikácii. Použi, keď používateľ explicitne chce ísť na obrazovku alebo otvoriť sekciu.',
          parameters: {
            type: 'object',
            properties: {
              screen: {
                type: 'string',
                enum: NAVIGATE_SCREENS,
                description: 'Identifikátor obrazovky v aplikácii',
              },
            },
            required: ['screen'],
          },
        },
      ],
    },
  ];
}

/** Konverzia klienta [{role, content}] -> Gemini contents (user / model). */
function clientMessagesToContents(messages) {
  const out = [];
  for (const m of messages) {
    if (m.role === 'user') {
      out.push({ role: 'user', parts: [{ text: m.content }] });
    } else if (m.role === 'assistant') {
      out.push({ role: 'model', parts: [{ text: m.content }] });
    }
  }
  return out;
}

function collectNavigateActionsFromParts(parts) {
  const actions = [];
  if (!parts || !Array.isArray(parts)) return actions;
  for (const p of parts) {
    const fc = p.functionCall;
    if (!fc || fc.name !== 'navigate') continue;
    const args = fc.args || {};
    const screen = args.screen;
    if (screen && NAVIGATE_SCREENS.includes(screen)) {
      actions.push({ type: 'navigate', screen });
    }
  }
  return actions;
}

function partsText(parts) {
  if (!parts || !Array.isArray(parts)) return '';
  return parts
    .filter((p) => p.text)
    .map((p) => p.text)
    .join('')
    .trim();
}

function buildModelTryList() {
  const primary = (process.env.GEMINI_MODEL || 'gemini-1.5-flash').trim();
  const extra = (process.env.GEMINI_MODEL_FALLBACKS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  /** Typické modely s odlišnými free-tier limitmi – používajú sa len pri chybe kvóty. */
  const defaults = ['gemini-1.5-flash', 'gemini-1.5-flash-8b'];
  const ordered = [primary, ...extra, ...defaults];
  return [...new Set(ordered)];
}

function isQuotaOrRateLimitError(err) {
  const msg = (err?.message || '').toLowerCase();
  return (
    err?.status === 429 ||
    msg.includes('quota') ||
    msg.includes('exceeded') ||
    msg.includes('resource_exhausted') ||
    msg.includes('rate limit')
  );
}

async function geminiGenerateContent({ apiKey, model, contents, systemInstruction }) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
    model
  )}:generateContent?key=${encodeURIComponent(apiKey)}`;

  const body = {
    contents,
    systemInstruction: {
      parts: [{ text: systemInstruction }],
    },
    tools: buildGeminiTools(),
    toolConfig: {
      functionCallingConfig: {
        mode: 'AUTO',
      },
    },
    generationConfig: {
      temperature: 0.4,
      maxOutputTokens: 1024,
    },
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = data.error?.message || data.error?.status || res.statusText || 'Gemini chyba';
    const err = new Error(msg);
    err.code = 'GEMINI';
    err.status = res.status;
    throw err;
  }
  return data;
}

/** Skúša modely v poradí, ak predchádzajúci zlyhá kvôli kvóte / limitu. */
async function geminiGenerateContentWithFallback({ apiKey, contents, systemInstruction }) {
  const models = buildModelTryList();
  let lastErr;
  for (let i = 0; i < models.length; i++) {
    const model = models[i];
    try {
      return await geminiGenerateContent({ apiKey, model, contents, systemInstruction });
    } catch (e) {
      lastErr = e;
      const retry = isQuotaOrRateLimitError(e) && i < models.length - 1;
      if (retry) {
        console.warn(`[POST /ai/assistant] model ${model}: ${e.message} – skúšam ďalší`);
      } else {
        throw e;
      }
    }
  }
  throw lastErr;
}

/**
 * @param {import('express').Router} apiRouter
 */
function registerAiAssistantRoutes(apiRouter) {
  const aiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 40,
    message: { success: false, error: 'Príliš veľa AI požiadaviek. Skúste neskôr.' },
    standardHeaders: true,
    legacyHeaders: false,
  });

  apiRouter.use('/ai', aiLimiter);

  apiRouter.post('/ai/assistant', async (req, res) => {
    const apiKey = getGeminiKey();
    if (!apiKey) {
      return res.status(503).json({
        success: false,
        error: 'AI asistent nie je na serveri zapnutý (chýba GEMINI_API_KEY).',
      });
    }

    const raw = req.body?.messages;
    if (!Array.isArray(raw) || raw.length === 0) {
      return res.status(400).json({ success: false, error: 'Pole messages je povinné.' });
    }
    if (raw.length > 50) {
      return res.status(400).json({ success: false, error: 'Príliš dlhá konverzácia.' });
    }

    const messages = [];
    for (const m of raw) {
      const role = m?.role;
      const content = typeof m?.content === 'string' ? m.content : '';
      if (role !== 'user' && role !== 'assistant') continue;
      if (content.length > 12000) {
        return res.status(400).json({ success: false, error: 'Správa je príliš dlhá.' });
      }
      if (content.trim().length === 0 && role === 'user') {
        return res.status(400).json({ success: false, error: 'Prázdna správa.' });
      }
      if (content.length > 0) messages.push({ role, content });
    }

    if (messages.length === 0 || messages[messages.length - 1].role !== 'user') {
      return res.status(400).json({ success: false, error: 'Očakáva sa aspoň jedna používateľská správa.' });
    }

    const allActions = [];
    let contents = clientMessagesToContents(messages);
    let lastReply = '';

    try {
      for (let round = 0; round < 4; round++) {
        const data = await geminiGenerateContentWithFallback({
          apiKey,
          contents,
          systemInstruction: SYSTEM_PROMPT,
        });

        const candidate = data.candidates?.[0];
        const blockReason = candidate?.finishReason;
        if (!candidate?.content?.parts?.length) {
          if (data.promptFeedback?.blockReason) {
            return res.status(400).json({
              success: false,
              error: 'Obsah bol zablokovaný bezpečnostným filtrom.',
            });
          }
          return res.status(502).json({ success: false, error: 'Prázdna odpoveď AI.' });
        }

        const parts = candidate.content.parts;
        const functionCalls = parts.filter((p) => p.functionCall);

        if (functionCalls.length > 0) {
          const nav = collectNavigateActionsFromParts(parts);
          allActions.push(...nav);

          contents = [...contents, { role: 'model', parts }];

          const responseParts = functionCalls.map((p) => {
            const name = p.functionCall.name;
            return {
              functionResponse: {
                name,
                response: { ok: true },
              },
            };
          });
          contents.push({ role: 'user', parts: responseParts });
          continue;
        }

        lastReply = partsText(parts);
        if (blockReason === 'MAX_TOKENS' && !lastReply) {
          lastReply = 'Odpoveď bola skrátená. Skúste kratšiu otázku.';
        }
        break;
      }

      return res.json({
        success: true,
        reply: lastReply || 'Hotovo.',
        actions: allActions,
      });
    } catch (err) {
      console.error('[POST /ai/assistant]', err.message);
      const status = err.status >= 400 && err.status < 600 ? err.status : 502;
      return res.status(status).json({
        success: false,
        error: err.message || 'Chyba AI služby',
      });
    }
  });
}

module.exports = { registerAiAssistantRoutes, NAVIGATE_SCREENS };
