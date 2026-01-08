FROM node:20-alpine AS base

# Installation des dépendances système nécessaires pour le build
RUN apk add --no-cache vips-dev build-base python3 g++ make

# --- Deps ---
FROM base AS deps
WORKDIR /app
COPY package.json yarn.lock ./

# Ajout des modules Redis et S3 nécessaires pour la Prod
RUN yarn add @medusajs/file-s3 @medusajs/event-bus-redis @medusajs/cache-redis
RUN yarn install --frozen-lockfile

# --- Builder ---
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Variables factices pour le build
ENV DATABASE_URL=postgres://fake:fake@localhost:5432/fake
ENV REDIS_URL=redis://localhost:6379
RUN yarn build

# --- Runner ---
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/.medusa ./.medusa
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/medusa-config.ts ./medusa-config.ts

COPY --from=builder /app/tsconfig.json ./tsconfig.json

# Sécurité : utilisateur non-root
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 medusa
RUN chown -R medusa:nodejs /app
USER medusa



EXPOSE 9000

CMD npx medusa db:migrate && npx medusa start