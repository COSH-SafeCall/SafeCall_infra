#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/home/ec2-user/safecall}"
INFRA_SOURCE_DIR="${INFRA_SOURCE_DIR:-/home/ec2-user/source/SafeCall_infra}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
SERVER_CONTAINER="${SERVER_CONTAINER:-safecall-server}"
NGINX_CONTAINER="${NGINX_CONTAINER:-safecall-nginx}"
DOMAIN="${DOMAIN:-api.dev-safecall.r-e.kr}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
SECRET_ID="${SECRET_ID:-safecall/prod}"
ENV_FILE="${ENV_FILE:-.env}"
SMOKE_URL="${SMOKE_URL:-http://localhost/error}"
SMOKE_EXPECTED_STATUS="${SMOKE_EXPECTED_STATUS:-404}"
SMOKE_MAX_ATTEMPTS="${SMOKE_MAX_ATTEMPTS:-30}"
SMOKE_SLEEP_SECONDS="${SMOKE_SLEEP_SECONDS:-5}"

cd "$DEPLOY_DIR"

mkdir -p nginx/conf.d scripts certbot/www certbot/conf keys

if [ -d "$INFRA_SOURCE_DIR" ]; then
    cp "$INFRA_SOURCE_DIR/docker-compose.prod.yml" "$COMPOSE_FILE"

    if [ -d "$INFRA_SOURCE_DIR/nginx" ]; then
        cp -a "$INFRA_SOURCE_DIR/nginx/." nginx/
    fi

    if [ -d "$INFRA_SOURCE_DIR/scripts" ]; then
        cp "$INFRA_SOURCE_DIR"/scripts/*.sh scripts/ 2>/dev/null || true
        chmod +x scripts/*.sh 2>/dev/null || true
    fi
fi

HTTPS_TEMPLATE="nginx/conf.d/safecall.https.conf.template"
CERT_PATH="certbot/conf/live/$DOMAIN/fullchain.pem"

certificate_exists() {
    docker compose -f "$COMPOSE_FILE" run --rm --entrypoint sh certbot \
        -c "test -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem" >/dev/null 2>&1
}

if certificate_exists && [ -f "$HTTPS_TEMPLATE" ]; then
    cp "$HTTPS_TEMPLATE" nginx/conf.d/safecall.conf
fi

umask 077
aws secretsmanager get-secret-value \
    --region "$AWS_REGION" \
    --secret-id "$SECRET_ID" \
    --query SecretString \
    --output text \
    | jq -r 'to_entries[] | "\(.key)=\(.value)"' > "$ENV_FILE"
chmod 600 "$ENV_FILE"

docker compose -f "$COMPOSE_FILE" config --quiet
docker compose -f "$COMPOSE_FILE" pull
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans safecall-server
docker compose -f "$COMPOSE_FILE" up -d --force-recreate --no-deps nginx
docker compose -f "$COMPOSE_FILE" ps

for attempt in $(seq 1 "$SMOKE_MAX_ATTEMPTS"); do
    status="$(curl -k -L -s -o /tmp/safecall-smoke.out -w '%{http_code}' "$SMOKE_URL" || true)"
    if [ "$status" = "$SMOKE_EXPECTED_STATUS" ]; then
        echo "Smoke check succeeded."
        docker image prune -af
        exit 0
    fi

    if [ "$attempt" -eq "$SMOKE_MAX_ATTEMPTS" ]; then
        echo "Smoke check failed after $SMOKE_MAX_ATTEMPTS attempts. last_status=$status"
        cat /tmp/safecall-smoke.out || true
        docker compose -f "$COMPOSE_FILE" ps
        docker logs --tail=200 "$SERVER_CONTAINER" || true
        docker logs --tail=100 "$NGINX_CONTAINER" || true
        exit 1
    fi

    echo "Smoke check is not ready yet. retrying... ($attempt/$SMOKE_MAX_ATTEMPTS, status=$status)"
    sleep "$SMOKE_SLEEP_SECONDS"
done
