# Build stage: compile React app
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --prefer-offline --no-audit
COPY . .
RUN npm run build

# Runtime stage: serve with nginx (pinned version — update deliberately)
# Check available tags at: https://hub.docker.com/_/nginx/tags
FROM nginx:1.27-alpine

# Ensure curl is available for the HEALTHCHECK
RUN apk add --no-cache curl

# Remove default static content and default vhost config
RUN rm -rf /usr/share/nginx/html/* /etc/nginx/conf.d/default.conf

# Custom vhost: listens on 8080 so the container runs without root privileges.
# Also adds React Router fallback and baseline security headers.
COPY --chown=nginx:nginx nginx.conf /etc/nginx/conf.d/default.conf

# Copy built assets; chown to nginx so the non-root user can serve them
COPY --from=builder --chown=nginx:nginx /app/build /usr/share/nginx/html

# Drop to the nginx system user — no root required at runtime
USER nginx

EXPOSE 8080

# Healthcheck: curl -f returns non-zero on 4xx/5xx, so bad deploys fail fast
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
