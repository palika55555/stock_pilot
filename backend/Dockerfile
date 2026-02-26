# Node.js backend pre Raspberry Pi (arm64)
FROM node:20-alpine

WORKDIR /app

# Závislosti najprv (lepší cache)
COPY package*.json ./
RUN npm ci --omit=dev

# Aplikácia
COPY . .

# Limity pre RPi: heap 256 MB, menej agresívny GC
ENV NODE_OPTIONS="--max-old-space-size=256 --gc-interval=100"

USER node

EXPOSE 3000

CMD ["node", "server.js"]
