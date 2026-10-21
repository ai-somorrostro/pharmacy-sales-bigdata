#!/usr/bin/env bash
# ------------------------------------------------------------------
# deploy.sh - Script único de despliegue (levantar, parar y limpiar)
# Uso: ./deploy.sh {up|down|clean} [-y|--yes]
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

usage() {
    echo "Uso: ./$SCRIPT_NAME {up|down|clean} [-y|--yes]"
    echo "  up     : Construye y levanta todos los contenedores en segundo plano."
    echo "  down   : Para y elimina los contenedores (mantiene los datos)."
    echo "  clean  : Para y borra contenedores, redes y volúmenes (limpieza total)."
    echo "           Con -y / --yes no pide confirmación."
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
        echo "🚀 Levantando los contenedores del reto..."
        docker compose up -d --build
        echo "✅ Servicios levantados correctamente. Puedes acceder a:"
        echo "   - InfluxDB: http://localhost:8087"
        echo "   - Grafana:  http://localhost:3000"
        echo "   - Node-RED: http://localhost:1881"
        echo "   - MCP InfluxDB: http://localhost:8001"
        echo "   - MCP Grafana: http://localhost:8000"
        echo
        docker compose ps
        ;;
    down)
        check_docker
        check_compose_file
        echo "🛑 Parando y eliminando los contenedores..."
        docker compose down
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
        docker compose down -v --remove-orphans
        echo "✨ Entorno limpiado por completo."
        ;;
    *)
        echo "❌ Opción no válida."
        usage
        exit 1
        ;;
esac