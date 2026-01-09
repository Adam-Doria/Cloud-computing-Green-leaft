FROM node:20-alpine AS base
RUN apk add --no-cache vips-dev build-base python3 g++ make

# --- 1. Installation ---
FROM base AS deps
WORKDIR /app
COPY package.json yarn.lock ./

# 👇 MODIFICATION ICI : On retire "--frozen-lockfile" pour qu'il s'adapte aux changements
RUN yarn install

# --- 2. Build ---
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Variables bidons pour le build
ENV NODE_ENV=production
ENV DATABASE_URL=postgres://fake:fake@localhost:5432/fake
ENV REDIS_URL=redis://localhost:6379

# A. Build de l'app Medusa
RUN npx medusa build

# B. Compilation du seed (Avec les bons flags pour éviter les erreurs TS2307)
RUN npx tsc src/scripts/seed.ts \
    --outDir .medusa/server/src/scripts \
    --target es2020 \
    --module commonjs \
    --moduleResolution node \
    --allowSyntheticDefaultImports \
    --skipLibCheck \
    --esModuleInterop \
    --resolveJsonModule

# --- 3. Runner ---
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 medusa

# On copie tout ce qu'il faut
COPY --from=builder --chown=medusa:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=medusa:nodejs /app/.medusa/server ./.medusa/server
COPY --from=builder --chown=medusa:nodejs /app/medusa-config.ts ./medusa-config.ts
COPY --from=builder --chown=medusa:nodejs /app/tsconfig.json ./tsconfig.json

USER medusa
EXPOSE 9000
WORKDIR /app/.medusa/server

# On lance le seed compilé (.js)
CMD npx medusa db:migrate && npx medusa && npx medusa start