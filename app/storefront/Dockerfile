FROM node:20-alpine AS base

# --- Deps ---
FROM base AS deps
WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn install

# --- Builder ---
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Désactiver la télémétrie Next.js
ENV NEXT_TELEMETRY_DISABLED=1
# Variables pour le build
ENV NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_dummy_build_key
ENV NEXT_PUBLIC_MEDUSA_BACKEND_URL=http://localhost:9000
# Démarrer un serveur fake (python) pour répondre 200 OK aux appels de build
RUN apk add --no-cache python3 && \
    python3 -c "from http.server import BaseHTTPRequestHandler, HTTPServer; \
    class Simple(BaseHTTPRequestHandler): \
        def do_GET(self): self.send_response(200); self.end_headers(); self.wfile.write(b'{}'); \
    HTTPServer(('localhost', 9000), Simple).serve_forever()" & \
    PID=$! && \
    sleep 3 && \
    yarn build && \
    kill $PID

# --- Runner ---
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copie des fichiers buildés (Standalone mode est activé par défaut en général)
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 8000
ENV PORT=8000
# On pointe vers l'API interne (Caddy ou localhost selon le contexte)
ENV NEXT_PUBLIC_MEDUSA_BACKEND_URL=http://localhost:8000

CMD ["node", "server.js"]