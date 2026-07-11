#!/usr/bin/env bash
set -Eeuo pipefail

DEFAULT_PHP_VERSION="8.5"
PROJECT_NAME=""
PHP_VERSION="$DEFAULT_PHP_VERSION"
START_CONTAINERS=true
FRESH_DB=false
POSITIONAL=()

show_help() {
    cat <<'EOF'
Uso:
  ./setup-docker.sh
  ./setup-docker.sh 8.4
  ./setup-docker.sh nome-progetto 8.5
  ./setup-docker.sh --name nome-progetto --php 8.5
  ./setup-docker.sh --fresh-db

Opzioni:
  --name NOME       Usa un nome diverso da quello della cartella
  --php VERSIONE    Versione PHP, per esempio 8.4 oppure 8.5
  --fresh-db        Elimina il volume database esistente prima dell'avvio
  --no-start        Configura solamente il file .env
  -h, --help        Mostra questo aiuto

Valori predefiniti:
  nome progetto     nome della cartella corrente
  PHP               8.5
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            [[ $# -ge 2 ]] || { echo "Manca il valore dopo --name."; exit 1; }
            PROJECT_NAME="$2"
            shift 2
            ;;
        --php)
            [[ $# -ge 2 ]] || { echo "Manca il valore dopo --php."; exit 1; }
            PHP_VERSION="$2"
            shift 2
            ;;
        --fresh-db)
            FRESH_DB=true
            shift
            ;;
        --no-start)
            START_CONTAINERS=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Opzione sconosciuta: $1"
            show_help
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [[ ${#POSITIONAL[@]} -eq 1 ]]; then
    if [[ "${POSITIONAL[0]}" =~ ^[0-9]+\.[0-9]+$ ]]; then
        PHP_VERSION="${POSITIONAL[0]}"
    else
        PROJECT_NAME="${POSITIONAL[0]}"
    fi
elif [[ ${#POSITIONAL[@]} -eq 2 ]]; then
    PROJECT_NAME="${POSITIONAL[0]}"
    PHP_VERSION="${POSITIONAL[1]}"
elif [[ ${#POSITIONAL[@]} -gt 2 ]]; then
    echo "Troppi parametri."
    show_help
    exit 1
fi

if [[ ! "$PHP_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Versione PHP non valida: '$PHP_VERSION'. Usa un formato come 8.4 o 8.5."
    exit 1
fi

if [[ ! -f artisan || ! -f composer.json ]]; then
    echo "Esegui lo script dalla cartella principale del progetto Laravel."
    exit 1
fi

if [[ ! -f Dockerfile ]]; then
    echo "Dockerfile non trovato."
    exit 1
fi

COMPOSE_FILE=""
for candidate in docker-compose.yml compose.yaml compose.yml docker-compose.yaml; do
    if [[ -f "$candidate" ]]; then
        COMPOSE_FILE="$candidate"
        break
    fi
done

if [[ -z "$COMPOSE_FILE" ]]; then
    echo "File Docker Compose non trovato."
    exit 1
fi

if [[ ! -f docker-configs/nginx/app.conf ]]; then
    echo "Configurazione Nginx non trovata in docker-configs/nginx/app.conf."
    exit 1
fi

if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME="$(basename "$PWD")"
fi

normalize_kebab() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

PROJECT_SLUG="$(normalize_kebab "$PROJECT_NAME")"

if [[ -z "$PROJECT_SLUG" ]]; then
    echo "Non riesco a ricavare un nome valido per il progetto."
    exit 1
fi

DB_PREFIX="${PROJECT_SLUG//-/_}"
DB_DATABASE="${DB_PREFIX}_db"
DB_USERNAME="${DB_PREFIX}_user"
DB_PASSWORD="${DB_PREFIX}_pass"

if [[ ! -f .env ]]; then
    if [[ -f .env.example ]]; then
        cp .env.example .env
        echo "Creato .env partendo da .env.example."
    else
        touch .env
        echo "Creato un nuovo file .env."
    fi
fi

set_env_value() {
    local key="$1"
    local value="$2"
    local tmp_file

    tmp_file="$(mktemp)"

    awk -v key="$key" -v value="$value" '
        BEGIN {
            found = 0
            pattern = "^[[:space:]]*#?[[:space:]]*" key "="
        }

        $0 ~ pattern {
            if (!found) {
                print key "=" value
                found = 1
            }

            next
        }

        {
            print
        }

        END {
            if (!found) {
                print ""
                print key "=" value
            }
        }
    ' .env > "$tmp_file"

    cat "$tmp_file" > .env
    rm -f "$tmp_file"
}

set_env_value "COMPOSE_PROJECT_NAME" "$PROJECT_SLUG"
set_env_value "PHP_VERSION" "$PHP_VERSION"
set_env_value "UID" "$(id -u)"
set_env_value "GID" "$(id -g)"
set_env_value "APP_URL" "http://localhost"
set_env_value "APP_PORT" "80"
set_env_value "DB_CONNECTION" "mysql"
set_env_value "DB_HOST" "db"
set_env_value "DB_PORT" "3306"
set_env_value "DB_FORWARD_PORT" "3306"
set_env_value "DB_DATABASE" "$DB_DATABASE"
set_env_value "DB_USERNAME" "$DB_USERNAME"
set_env_value "DB_PASSWORD" "$DB_PASSWORD"
set_env_value "DB_ROOT_PASSWORD" "root"
set_env_value "MARIADB_VERSION" "11.8"
set_env_value "PHPMYADMIN_PORT" "8080"

echo
echo "Configurazione:"
echo "  Progetto Docker : $PROJECT_SLUG"
echo "  PHP             : $PHP_VERSION"
echo "  Database        : $DB_DATABASE"
echo "  Utente database : $DB_USERNAME"
echo "  File Compose    : $COMPOSE_FILE"
echo

docker compose -f "$COMPOSE_FILE" config >/dev/null
echo "Configurazione Compose valida."

if [[ "$START_CONTAINERS" == false ]]; then
    echo "Configurazione completata senza avviare Docker."
    exit 0
fi

if [[ "$FRESH_DB" == true ]]; then
    echo "Eliminazione dei container e del volume database esistenti..."
    docker compose -f "$COMPOSE_FILE" down -v --remove-orphans || true
fi

echo "Costruzione del container PHP..."
docker compose -f "$COMPOSE_FILE" build --pull web

echo "Avvio dei servizi..."
docker compose -f "$COMPOSE_FILE" up -d

echo "Installazione/verifica dipendenze Composer..."
docker compose -f "$COMPOSE_FILE" exec -T web composer install

if grep -qE '^APP_KEY=$' .env || ! grep -qE '^APP_KEY=' .env; then
    echo "Generazione APP_KEY..."
    docker compose -f "$COMPOSE_FILE" exec -T web php artisan key:generate
fi

if [[ -f package.json && ! -d node_modules ]]; then
    echo "Installazione dipendenze Node..."
    docker compose -f "$COMPOSE_FILE" exec -T web npm install
fi

echo
echo "Verifiche:"
docker compose -f "$COMPOSE_FILE" exec -T web php -v | head -n 1
docker compose -f "$COMPOSE_FILE" exec -T nginx nginx -t
docker compose -f "$COMPOSE_FILE" ps

echo
echo "Setup completato."
echo "  Sito       : http://localhost"
echo "  phpMyAdmin : http://localhost:8080"
echo
echo "Le migrazioni non sono state eseguite automaticamente."
echo "Quando sei pronto:"
echo "  docker compose exec web php artisan migrate"
