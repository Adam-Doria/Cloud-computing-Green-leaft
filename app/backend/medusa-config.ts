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
        path: "/app",
        backendUrl: process.env.MEDUSA_BACKEND_URL,
        vite: (config) => {
            return {
                ...config,
                server: {
                    ...config.server,
                    host: "0.0.0.0",
                    allowedHosts: ['.amazonaws.com', 'localhost', '127.0.0.1', 'medusa-backend', 'domaine-du-client.com'],
                    hmr: {
                        ...config.server?.hmr,
                        port: 5173,
                        clientPort: 5173,
                    },
                },
            }
        },
    },
    modules: [
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
                            region: "auto",
                            bucket: "greenleaf-media",
                            endpoint: process.env.S3_URL,
                        },
                    },
                ],
            },
        },
        {
            resolve: "@medusajs/medusa/event-bus-redis",
            options: {
                redisUrl: process.env.REDIS_URL
            },
        },
        {
            resolve: "@medusajs/medusa/cache-redis",
            options: {
                redisUrl: process.env.REDIS_URL
            },
        },
    ]
})