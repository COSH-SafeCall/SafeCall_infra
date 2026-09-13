#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/home/ec2-user/safecall}"
INFRA_SOURCE_DIR="${INFRA_SOURCE_DIR:-/home/ec2-user/source/SafeCall_infra}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
DOMAIN="${DOMAIN:-api.dev-safecall.r-e.kr}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
STAGING="${STAGING:-0}"
NGINX_CONTAINER="${NGINX_CONTAINER:-safecall-nginx}"

if [ -z "$LETSENCRYPT_EMAIL" ]; then
    echo "LETSENCRYPT_EMAIL is required."
    echo "example: LETSENCRYPT_EMAIL=team@example.com bash scripts/init-letsencrypt.sh"
    exit 1
fi

cd "$DEPLOY_DIR"

mkdir -p nginx/conf.d scripts certbot/www certbot/conf keys

if [ -d "$INFRA_SOURCE_DIR" ]; then
    cp "$INFRA_SOURCE_DIR/docker-compose.prod.yml" "$COMPOSE_FILE"

    if [ -d "$INFRA_SOURCE_DIR/nginx" ]; then
        rm -rf nginx
        cp -r "$INFRA_SOURCE_DIR/nginx" nginx
    fi

    if [ -d "$INFRA_SOURCE_DIR/scripts" ]; then
        cp "$INFRA_SOURCE_DIR"/scripts/*.sh scripts/ 2>/dev/null || true
        chmod +x scripts/*.sh 2>/dev/null || true
    fi
fi

if [ ! -f "nginx/conf.d/safecall.conf" ]; then
    echo "nginx/conf.d/safecall.conf is missing."
    exit 1
fi

docker compose -f "$COMPOSE_FILE" up -d nginx

if [ -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
    echo "Certificate already exists for $DOMAIN. Switching nginx to HTTPS config."
else
    staging_args=()
    if [ "$STAGING" = "1" ]; then
        staging_args=(--staging)
    fi

    docker compose -f "$COMPOSE_FILE" run --rm certbot certonly \
        --webroot \
        --webroot-path /var/www/certbot \
        --email "$LETSENCRYPT_EMAIL" \
        --agree-tos \
        --no-eff-email \
        --keep-until-expiring \
        "${staging_args[@]}" \
        -d "$DOMAIN"
fi

if [ ! -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
    echo "Certificate was not created: certbot/conf/live/$DOMAIN/fullchain.pem"
    exit 1
fi

if [ ! -f "nginx/conf.d/safecall.https.conf.template" ]; then
    echo "nginx/conf.d/safecall.https.conf.template is missing."
    exit 1
fi

cp nginx/conf.d/safecall.https.conf.template nginx/conf.d/safecall.conf

if docker compose -f "$COMPOSE_FILE" exec -T "$NGINX_CONTAINER" nginx -t; then
    docker compose -f "$COMPOSE_FILE" exec -T "$NGINX_CONTAINER" nginx -s reload
else
    docker compose -f "$COMPOSE_FILE" restart "$NGINX_CONTAINER"
fi

echo "HTTPS is ready for $DOMAIN."
