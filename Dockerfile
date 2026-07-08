# --- Stage 1: Build ---
FROM node:22-slim AS build
WORKDIR /app

# Install OpenSSL and PostgreSQL client tools for Prisma's PostgreSQL engine
RUN apt-get update -y && apt-get install -y openssl postgresql-client

# Install all dependencies (including dev tools)
COPY package*.json ./
RUN npm ci

# Copy source code
COPY . .

# Generate Prisma client from the PostgreSQL schema before building
RUN npx prisma generate --schema=src/prisma/schema.prisma
# Compile the Nx application
RUN npx nx build api


# --- Stage 2: Production Runtime ---
FROM node:22-slim
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3000
WORKDIR /app

# Install OpenSSL and curl for runtime and clean up to keep image small
RUN apt-get update -y && apt-get install -y openssl curl && rm -rf /var/lib/apt/lists/*

# Install ONLY production dependencies
COPY package*.json ./
RUN npm ci --omit=dev

# Copy compiled app, assets, and the generated Prisma client
COPY --from=build /app/dist ./dist
COPY --from=build /app/src/assets ./src/assets
COPY --from=build /app/node_modules/.prisma/client ./node_modules/.prisma/client

# Secure the container with a non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 3000

# Start the compiled application
CMD [ "node", "dist/api/main.js" ]