FROM node:20-alpine AS base
# Installe les outils systèmes (Python/Make pour le build)
RUN apk add --no-cache vips-dev build-base python3 g++ make

# --- Étape 1 : Installation des dépendances ---
FROM base AS deps
WORKDIR /app
COPY package.json yarn.lock ./
# Installe tout ce qu'il faut
RUN yarn install --frozen-lockfile

# --- Étape 2 : Build ---
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Variables temporaires pour le build
ENV NODE_ENV=production
ENV DATABASE_URL=postgres://fake:fake@localhost:5432/fake
ENV REDIS_URL=redis://localhost:6379

# C'est ici que l'admin (index.html) et le server sont créés
RUN npx medusa build

# IMPORTANT: Installer les dépendances dans .medusa/server (documentation officielle)
WORKDIR /app/.medusa/server
RUN yarn install --frozen-lockfile

# --- Étape 3 : Runner (Production) ---
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production

# COPIE CRITIQUE : On ramène tout ce qui est nécessaire
COPY --from=builder /app/.medusa/server ./.medusa/server
COPY --from=builder /app/medusa-config.ts ./medusa-config.ts
COPY --from=builder /app/tsconfig.json ./tsconfig.json

# Permissions
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 medusa && \
    chown -R medusa:nodejs /app

USER medusa

EXPOSE 9000

# IMPORTANT: Exécuter depuis .medusa/server (documentation officielle)
WORKDIR /app/.medusa/server
CMD npx medusa db:migrate && npx medusa start