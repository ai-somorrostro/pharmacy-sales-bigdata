#!/bin/bash

# Nombre del archivo de script
SCRIPT_NAME=$(basename "$0")

# Comprobar si existe el fichero .env
check_env() {
    if [ ! -f .env ]; then
        echo "⚠️  No se encuentra el fichero .env."
        if [ -f .env.example ]; then
            echo "📋 Copiando .env.example a .env..."
            cp .env.example .env
            echo "👉 Edita el fichero .env con tus tokens y contraseñas reales antes de continuar."
        else
            echo "❌ Error: No se encontró .env ni .env.example."
        fi
        exit 1
    fi
}

case "$1" in
    up)
        check_env
        echo "🚀 Levantando los contenedores del reto..."
        docker compose up -d --build
        echo "✅ Servicios levantados correctamente. Puedes acceder a:"
        echo "   - InfluxDB: http://localhost:8086"
        echo "   - Grafana:  http://localhost:3000"
        echo "   - Node-RED: http://localhost:1880"
        echo "   - MCP:      http://localhost:8080"
        ;;
    down)
        echo "🛑 Parando y eliminando los contenedores..."
        docker compose down
        echo "✅ Servicios detenidos."
        ;;
    clean)
        echo "🧹 Limpiando todo: contenedores, redes y volúmenes de datos..."
        read -p "⚠️  ¿Estás seguro de que quieres borrar todos los datos almacenados? (s/N): " confirm
        if [[ "$confirm" =~ ^[Ss]$ ]]; then
            docker compose down -v
            echo "✨ Entorno limpiado por completo."
        else
            echo "Operación cancelada."
        fi
        ;;
    *)
        echo "❌ Opción no válida."
        echo "Uso: ./$SCRIPT_NAME {up|down|clean}"
        echo "  - up    : Crea y levanta todos los contenedores en segundo plano."
        echo "  - down  : Para y elimina los contenedores (mantiene los datos)."
        echo "  - clean : Para y borra contenedores y volúmenes (limpieza total)."
        exit 1
        ;;
esac