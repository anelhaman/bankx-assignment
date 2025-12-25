# --- Build Stage ---
FROM node:18-alpine AS build

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache dumb-init

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY app/ ./

# --- Runtime Stage ---
FROM node:18-alpine

WORKDIR /app

# Install dumb-init for signal handling
RUN apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy only necessary files from build stage
COPY --from=build /app /app

# Change ownership
RUN chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

ENTRYPOINT ["/sbin/dumb-init", "--"]
CMD ["node", "app.js"]
