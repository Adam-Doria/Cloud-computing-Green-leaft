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
RUN yarn build

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