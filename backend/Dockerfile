# Node.js backend pre Raspberry Pi (arm64)
FROM node:20-alpine

# curl pre Coolify healthcheck (v Alpine defaultne nie je)
RUN apk add --no-cache curl

WORKDIR /app

# Závislosti najprv (lepší cache)
COPY package*.json ./
RUN npm install --omit=dev

# Aplikácia
COPY . .

# Limity pre RPi: heap 256 MB (--gc-interval nie je povolený v NODE_OPTIONS)
ENV NODE_OPTIONS="--max-old-space-size=256"

USER node

EXPOSE 3000

CMD ["node", "server.js"]
