import { loadEnv, defineConfig } from '@medusajs/framework/utils'

loadEnv(process.env.NODE_ENV || 'development', process.cwd())

module.exports = defineConfig({
    projectConfig: {
        databaseUrl: process.env.DATABASE_URL,
        databaseDriverOptions: {
            ssl: {
                rejectUnauthorized: false,
            },
            connection: {
                ssl: {
                    rejectUnauthorized: false,
                },
            },
        },
        // Redis est maintenant configuré ici pour le cache et les événements
        redisUrl: process.env.REDIS_URL,
        http: {
            storeCors: process.env.STORE_CORS!,
            adminCors: process.env.ADMIN_CORS!,
            authCors: process.env.AUTH_CORS!,
            jwtSecret: process.env.JWT_SECRET || "supersecret",
            cookieSecret: process.env.COOKIE_SECRET || "supersecret",
        }
    },
    admin: {
        disable: false,
        path: `/app`,
        backendUrl: process.env.MEDUSA_BACKEND_URL,
    },
    modules: [
        // Configuration du stockage S3 (Cloudflare R2)
        {
            resolve: "@medusajs/medusa/file",
            options: {
                providers: [
                    {
                        resolve: "@medusajs/file-s3",
                        id: "s3",
                        options: {
                            file_url: process.env.S3_URL,
                            access_key_id: process.env.S3_ACCESS_KEY_ID,
                            secret_access_key: process.env.S3_SECRET_ACCESS_KEY,
                            region: "auto", // Cloudflare R2 utilise souvent "auto" ou "us-east-1"
                            bucket: "greenleaf-media", // Nom de ton bucket
                            endpoint: process.env.S3_URL,
                        },
                    },
                ],
            },
        },
        // Configuration Redis pour le Pub/Sub (Événements)
        {
            resolve: "@medusajs/medusa/event-bus-redis",
            options: {
                redisUrl: process.env.REDIS_URL
            },
        },
        // Configuration Redis pour le Cache
        {
            resolve: "@medusajs/medusa/cache-redis",
            options: {
                redisUrl: process.env.REDIS_URL
            },
        },
    ]
})