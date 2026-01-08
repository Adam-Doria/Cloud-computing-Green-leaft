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

# Variables pour le build (valeurs dummy pour que le build passe)
ENV NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_dummy_build_key
ENV NEXT_PUBLIC_MEDUSA_BACKEND_URL=http://localhost:9000
ENV NEXT_SKIP_PRERENDERS=1

# Le build standard (les erreurs de connexion au back sont gérées par vos try/catch dans le code)
RUN yarn build

# --- Runner ---
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copie des fichiers buildés
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

# Port du Storefront (Next.js)
EXPOSE 8000
ENV PORT=8000

# 1. URL publique pour le navigateur (Client-side) -> Doit pointer vers le port du Backend
ENV NEXT_PUBLIC_MEDUSA_BACKEND_URL=http://localhost:9000

# 2. URL interne pour le serveur Next.js (SSR) -> Doit pointer vers le conteneur Backend
ENV MEDUSA_BACKEND_URL=http://medusa-backend:9000

CMD ["node", "server.js"]