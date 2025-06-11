# Supabase Studio Dockerfile
FROM node:18-alpine AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copy package files from the supabase monorepo
COPY supabase/package.json supabase/pnpm-lock.yaml ./
COPY supabase/pnpm-workspace.yaml ./
RUN npm install -g pnpm@9
RUN pnpm install --frozen-lockfile

# Builder stage
FROM node:18-alpine AS builder
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copy dependencies and source
COPY --from=deps /app/node_modules ./node_modules
COPY supabase/ ./

# Build Studio
RUN npm install -g pnpm@9
RUN pnpm build:studio

# Runner stage
FROM node:18-alpine AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy built application
COPY --from=builder /app/apps/studio/.next/standalone ./
COPY --from=builder /app/apps/studio/.next/static ./apps/studio/.next/static
COPY --from=builder /app/apps/studio/public ./apps/studio/public

# Copy configuration files
COPY docker/studio/config.json ./apps/studio/config.json

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "apps/studio/server.js"]