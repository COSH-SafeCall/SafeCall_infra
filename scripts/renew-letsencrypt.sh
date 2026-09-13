#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/home/ec2-user/safecall}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
DOMAIN="${DOMAIN:-api.dev-safecall.r-e.kr}"
NGINX_CONTAINER="${NGINX_CONTAINER:-nginx}"

cd "$DEPLOY_DIR"

docker compose -f "$COMPOSE_FILE" run --rm certbot renew --webroot -w /var/www/certbot

certificate_exists() {
    docker compose -f "$COMPOSE_FILE" run --rm --entrypoint sh certbot \
        -c "test -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem" >/dev/null 2>&1
}

if certificate_exists && [ -f "nginx/conf.d/safecall.https.conf.template" ]; then
    cp nginx/conf.d/safecall.https.conf.template nginx/conf.d/safecall.conf
fi

if docker compose -f "$COMPOSE_FILE" exec -T "$NGINX_CONTAINER" nginx -t; then
    docker compose -f "$COMPOSE_FILE" exec -T "$NGINX_CONTAINER" nginx -s reload
else
    docker compose -f "$COMPOSE_FILE" restart "$NGINX_CONTAINER"
fi

echo "Certificate renewal check completed for $DOMAIN."
