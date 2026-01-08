FROM node:20-alpine AS base

# --- Deps ---
FROM base AS deps
WORKDIR /app
COPY package.json yarn.lock ./

# Ajout des modules Redis et S3 nécessaires pour la Prod
RUN yarn add @medusajs/file-s3 @medusajs/event-bus-redis @medusajs/cache-redis

# --- Builder ---
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Variables factices pour le build (la vraie config vient du runtime)
ENV DATABASE_URL=postgres://fake:fake@localhost:5432/fake
ENV REDIS_URL=redis://localhost:6379
RUN yarn build

# --- Runner ---
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/.medusa/server ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/medusa-config.ts ./medusa-config.ts

# Sécurité : utilisateur non-root
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 medusa
USER medusa

EXPOSE 9000

CMD npx medusa db:migrate && npx medusa start