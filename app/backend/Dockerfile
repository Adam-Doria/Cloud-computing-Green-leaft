FROM node:20-alpine AS base

# --- Étape 1 : Installation des dépendances ---
FROM base AS deps
WORKDIR /app
COPY package.json yarn.lock ./

RUN yarn add @medusajs/file-s3 @medusajs/medusa @medusajs/event-bus-redis @medusajs/cache-redis
RUN yarn install --frozen-lockfile
# On ajoute le plugin S3 ici car il manque dans le starter
RUN yarn add @medusajs/file-s3 @medusajs/medusa
RUN yarn install --frozen-lockfile

# --- Étape 2 : Build du code TypeScript ---
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Build de l'application Medusa V2
RUN yarn build

# --- Étape 3 : Image de Production ---
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production

# On copie uniquement le nécessaire
COPY --from=builder /app/.medusa/server ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
# Important : Medusa V2 a besoin du fichier config compilé ou source
COPY --from=builder /app/medusa-config.ts ./medusa-config.ts

# Création d'un utilisateur non-root pour la sécurité
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 medusa
USER medusa

EXPOSE 9000

# Commande de démarrage : Migrations DB -> Start
CMD npx medusa db:migrate && npx medusa start