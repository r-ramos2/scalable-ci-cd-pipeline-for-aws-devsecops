# Build stage: compile React app
FROM node:16 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --prefer-offline --no-audit
COPY . .
RUN npm run build

# Runtime stage: serve with nginx (alpine)
FROM nginx:stable-alpine

# Ensure curl for healthcheck
RUN apk add --no-cache curl

# Remove default content
RUN rm -rf /usr/share/nginx/html/*

# Copy built assets
COPY --from=builder /app/build /usr/share/nginx/html

# Expose HTTP
EXPOSE 80

# Healthcheck: use curl -f (returns non-zero if page not healthy)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
