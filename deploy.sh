#!/usr/bin/env bash
# ------------------------------------------------------------------
# deploy.sh - Script único de despliegue (levantar, parar y limpiar)
# Uso: ./deploy.sh {up|influx-tokens|mcp-token|down|clean} [-y|--yes]
# ------------------------------------------------------------------
set -euo pipefail

SCRIPT_NAME=$(basename "$0")

# Ejecutar siempre desde la carpeta del script (donde está docker-compose.yml)
cd "$(dirname "$0")"

# ---------- Comprobaciones previas ----------
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ Docker no está instalado."
        exit 1
    fi
    if ! docker compose version >/dev/null 2>&1; then
        echo "❌ 'docker compose' (v2) no está disponible."
        exit 1
    fi
    if ! docker info >/dev/null 2>&1; then
        echo "❌ El daemon de Docker no está en ejecución (o no tienes permisos)."
        exit 1
    fi
}

check_compose_file() {
    if [ ! -f docker-compose.yml ] && [ ! -f docker-compose.yaml ] && [ ! -f compose.yml ]; then
        echo "❌ No se encuentra el fichero docker-compose.yml en $(pwd)."
        exit 1
    fi
}

check_env() {
    if [ ! -f .env ]; then
        echo "⚠️  No se encuentra el fichero .env."
        if [ -f .env.example ]; then
            echo "📋 Copiando .env.example a .env..."
            cp .env.example .env
            echo "👉 Edita el fichero .env con tus tokens y contraseñas reales y vuelve a ejecutar."
        else
            echo "❌ Error: No se encontró .env ni .env.example."
        fi
        exit 1
    fi
}

# ---------- Utilidades para .env ----------
# Lee el valor de una variable del .env (sin comillas). Vacío si no existe.
env_get() {
    local value
    value=$(grep -E "^$1=" .env | tail -n 1 | cut -d= -f2- || true)
    value="${value%\"}"; value="${value#\"}"
    value="${value%\'}"; value="${value#\'}"
    printf '%s' "$value"
}

# Escribe (o añade) una variable en el .env sin tocar el resto del fichero.
env_set() {
    local tmp
    tmp=$(mktemp)
    if grep -qE "^$1=" .env; then
        awk -v k="$1" -v v="$2" 'index($0, k "=") == 1 { print k "=" v; next } { print }' .env > "$tmp"
    else
        cat .env > "$tmp"
        printf '\n%s=%s\n' "$1" "$2" >> "$tmp"
    fi
    cat "$tmp" > .env
    rm -f "$tmp"
}

# ---------- Tokens de lectura/escritura de InfluxDB ----------
wait_influx() {
    echo "⏳ Esperando a que InfluxDB esté listo..."
    for _ in $(seq 1 60); do
        if docker compose exec -T influxdb influx ping >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    echo "❌ InfluxDB no responde. Revisa: docker compose logs influxdb"
    exit 1
}

create_influx_tokens() {
    local out read_token write_token
    docker compose up -d influxdb
    wait_influx

    echo "🔑 Creando los tokens de lectura (Grafana) y escritura (Node-RED)..."
    if ! out=$(docker compose exec -T influxdb sh -s < BDA/influxdb/create-tokens.sh); then
        echo "❌ No se pudieron crear los tokens."
        echo "   Si cambiaste INFLUX_ADMIN_TOKEN o INFLUX_ORG después del primer arranque,"
        echo "   InfluxDB sigue usando los valores con los que se creó el volumen."
        echo "   Vuelve a los valores originales o empieza de cero con: ./$SCRIPT_NAME clean"
        exit 1
    fi
    read_token=$(printf '%s\n' "$out" | sed -n 's/^INFLUX_READ_TOKEN=//p')
    write_token=$(printf '%s\n' "$out" | sed -n 's/^INFLUX_WRITE_TOKEN=//p')
    if [ -z "$read_token" ] || [ -z "$write_token" ]; then
        echo "❌ InfluxDB no devolvió los tokens. Salida:"
        echo "$out"
        exit 1
    fi

    env_set INFLUX_READ_TOKEN "$read_token"
    env_set INFLUX_WRITE_TOKEN "$write_token"
    echo "✅ Tokens guardados en .env (INFLUX_READ_TOKEN e INFLUX_WRITE_TOKEN)."

    # Grafana y Node-RED leen los tokens del entorno al arrancar: se recrean
    echo "🔄 Reiniciando Grafana y Node-RED con los tokens nuevos..."
    docker compose up -d --build grafana nodered
    echo "✅ Listo."
}

# ---------- Token de la service account de Grafana para el MCP ----------
GRAFANA_URL="http://127.0.0.1:3000"
MCP_SA_NAME="mcp-grafana"

mcp_port() {
    local port
    port=$(env_get GRAFANA_MCP_PORT)
    printf '%s' "${port:-8000}"
}

wait_grafana() {
    echo "⏳ Esperando a que Grafana responda en $GRAFANA_URL..."
    for _ in $(seq 1 60); do
        if curl -fsS "$GRAFANA_URL/api/health" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    echo "❌ Grafana no responde. Revisa: docker compose logs grafana"
    exit 1
}

create_mcp_token() {
    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ Se necesita 'curl' para hablar con la API de Grafana."
        exit 1
    fi

    local user pass role auth resp code body sa_id token
    user=$(env_get GRAFANA_ADMIN_USER)
    pass=$(env_get GRAFANA_ADMIN_PASSWORD)
    role=$(env_get GRAFANA_MCP_ROLE)
    role="${role:-Viewer}"
    if [ -z "$user" ] || [ -z "$pass" ]; then
        echo "❌ Define GRAFANA_ADMIN_USER y GRAFANA_ADMIN_PASSWORD en .env."
        exit 1
    fi
    auth="$user:$pass"

    # Grafana tiene que estar arriba para poder crear la service account
    docker compose up -d grafana
    wait_grafana

    # 1) Crear la service account (o reutilizarla si ya existe)
    echo "👤 Creando la service account '$MCP_SA_NAME' (rol $role)..."
    resp=$(curl -sS -u "$auth" -H "Content-Type: application/json" \
        -w '\n%{http_code}' -X POST "$GRAFANA_URL/api/serviceaccounts" \
        -d "{\"name\":\"$MCP_SA_NAME\",\"role\":\"$role\",\"isDisabled\":false}")
    code=$(printf '%s' "$resp" | tail -n 1)
    body=$(printf '%s' "$resp" | sed '$d')

    if [ "$code" = "401" ]; then
        echo "❌ Grafana rechaza el usuario/contraseña de admin del .env."
        echo "   Ojo: GRAFANA_ADMIN_PASSWORD solo se aplica la primera vez que arranca Grafana;"
        echo "   si la cambiaste después, usa la contraseña con la que se creó el volumen."
        exit 1
    elif [ "$code" = "201" ] || [ "$code" = "200" ]; then
        sa_id=$(printf '%s' "$body" | grep -oE '"id": *[0-9]+' | head -n 1 | tr -dc '0-9')
    else
        # Ya existe: la buscamos por nombre
        body=$(curl -fsS -u "$auth" "$GRAFANA_URL/api/serviceaccounts/search?query=$MCP_SA_NAME")
        sa_id=$(printf '%s' "$body" | grep -oE '"id": *[0-9]+' | head -n 1 | tr -dc '0-9')
        [ -n "$sa_id" ] && echo "ℹ️  La service account ya existía (id $sa_id); se reutiliza."
    fi
    if [ -z "${sa_id:-}" ]; then
        echo "❌ No se pudo crear ni encontrar la service account. Respuesta de Grafana:"
        echo "$body"
        exit 1
    fi

    # 2) Crear un token nuevo para esa service account
    echo "🔑 Generando token..."
    body=$(curl -fsS -u "$auth" -H "Content-Type: application/json" \
        -X POST "$GRAFANA_URL/api/serviceaccounts/$sa_id/tokens" \
        -d "{\"name\":\"mcp-token-$(date +%Y%m%d-%H%M%S)-$$\"}")
    token=$(printf '%s' "$body" | grep -oE '"key": *"[^"]*"' | head -n 1 | sed -E 's/.*"([^"]*)"$/\1/')
    if [ -z "$token" ]; then
        echo "❌ No se pudo generar el token. Respuesta de Grafana:"
        echo "$body"
        exit 1
    fi

    # 3) Guardarlo en .env
    env_set GRAFANA_MCP_TOKEN "$token"
    echo "✅ Token guardado en .env (GRAFANA_MCP_TOKEN)."

    # 4) Token que presentan los clientes MCP (opencode) frente al servidor.
    #    No depende de Grafana: si falta o es el de ejemplo, se genera uno.
    local server_token
    server_token=$(env_get MCP_GRAFANA_SERVER_TOKEN)
    if [ -z "$server_token" ] || printf '%s' "$server_token" | grep -q "ejemplo"; then
        if command -v openssl >/dev/null 2>&1; then
            server_token=$(openssl rand -hex 32)
        else
            server_token=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
        fi
        env_set MCP_GRAFANA_SERVER_TOKEN "$server_token"
        echo "✅ Token de clientes MCP generado y guardado en .env (MCP_GRAFANA_SERVER_TOKEN)."
    fi
    # opencode.json lo lee de mcp-token.txt (ignorado por git)
    printf '%s' "$server_token" > mcp-token.txt
    echo "✅ mcp-token.txt actualizado para opencode."
    echo "🚀 Arrancando mcp-grafana..."
    docker compose --profile mcp up -d mcp-grafana
    echo "✅ MCP Grafana disponible en http://127.0.0.1:$(mcp_port)/mcp"
}

usage() {
    echo "Uso: ./$SCRIPT_NAME {up|influx-tokens|mcp-token|down|clean} [-y|--yes]"
    echo "  up            : Construye y levanta todos los contenedores en segundo plano."
    echo "                  El MCP de Grafana solo se levanta si GRAFANA_MCP_TOKEN tiene valor."
    echo "  influx-tokens : Crea en InfluxDB los tokens de lectura (Grafana) y escritura"
    echo "                  (Node-RED), los guarda en .env y reinicia esos servicios."
    echo "  mcp-token     : Crea la service account del MCP en Grafana, guarda su token en"
    echo "                  .env, prepara mcp-token.txt para opencode y arranca mcp-grafana."
    echo "  down          : Para y elimina los contenedores (mantiene los datos)."
    echo "  clean         : Para y borra contenedores, redes y volúmenes (limpieza total)."
    echo "                  Con -y / --yes no pide confirmación."
    echo
    echo "Primer arranque: ./$SCRIPT_NAME up && ./$SCRIPT_NAME influx-tokens && ./$SCRIPT_NAME mcp-token"
}

# ---------- Argumentos ----------
ACTION="${1:-}"
ASSUME_YES=false
if [ "${2:-}" = "-y" ] || [ "${2:-}" = "--yes" ]; then
    ASSUME_YES=true
fi

# ---------- Acciones ----------
case "$ACTION" in
    up)
        check_docker
        check_compose_file
        check_env
        PROFILE_ARGS=()
        if [ -n "$(env_get GRAFANA_MCP_TOKEN)" ]; then
            PROFILE_ARGS=(--profile mcp)
        fi
        echo "🚀 Levantando los contenedores del reto..."
        docker compose ${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"} up -d --build
        echo "✅ Servicios levantados correctamente. Puedes acceder a:"
        echo "   - InfluxDB: http://127.0.0.1:8087"
        echo "   - Grafana:  http://127.0.0.1:3000"
        echo "   - Node-RED: http://127.0.0.1:1881"
        if [ -z "$(env_get INFLUX_READ_TOKEN)" ] || [ -z "$(env_get INFLUX_WRITE_TOKEN)" ]; then
            echo
            echo "⚠️  Faltan INFLUX_READ_TOKEN / INFLUX_WRITE_TOKEN: Grafana no podrá leer ni Node-RED escribir."
            echo "   Para crearlos: ./$SCRIPT_NAME influx-tokens"
        fi
        if [ ${#PROFILE_ARGS[@]} -gt 0 ]; then
            echo "   - MCP Grafana: http://127.0.0.1:$(mcp_port)/mcp"
        else
            echo
            echo "ℹ️  MCP Grafana no se ha levantado porque GRAFANA_MCP_TOKEN está vacío."
            echo "   Para crear el token y arrancarlo: ./$SCRIPT_NAME mcp-token"
        fi
        echo
        docker compose ${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"} ps
        ;;
    down)
        check_docker
        check_compose_file
        echo "🛑 Parando y eliminando los contenedores..."
        docker compose --profile mcp down
        echo "✅ Servicios detenidos (los datos se conservan)."
        ;;
    clean)
        check_docker
        check_compose_file
        echo "🧹 Limpieza total: contenedores, redes y volúmenes de datos."
        if [ "$ASSUME_YES" = false ]; then
            read -r -p "⚠️  ¿Seguro que quieres borrar todos los datos almacenados? (s/N): " confirm
            if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
                echo "Operación cancelada."
                exit 0
            fi
        fi
        docker compose --profile mcp down -v --remove-orphans
        echo "✨ Entorno limpiado por completo."
        ;;
    influx-tokens)
        check_docker
        check_compose_file
        check_env
        create_influx_tokens
        ;;
    mcp-token)
        check_docker
        check_compose_file
        check_env
        create_mcp_token
        ;;
    *)
        echo "❌ Opción no válida."
        usage
        exit 1
        ;;
esac