# --- Web build ---
FROM haxe:4.3.7-alpine AS builder
WORKDIR /app
RUN haxelib install heaps --always
COPY src/ ./src/
COPY res/ ./res/
COPY build.hxml index.html stamp.sh ./
RUN haxe build.hxml && sh stamp.sh

# --- Static server ---
FROM nginx:alpine

LABEL org.opencontainers.image.source=https://github.com/platypod/unbegotten

COPY --from=builder /app/bin /usr/share/nginx/html

# Replaces the stock default, which sent no Cache-Control at all and so let
# browsers guess a freshness lifetime for a bundle whose filename never
# changes. See nginx.conf's own header.
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
