#!/bin/sh
# ------------------------------------------------------------------
# create-tokens.sh - Crea los tokens de lectura (Grafana) y escritura
# (Node-RED) en InfluxDB, con permisos solo sobre los buckets del reto.
#
# Se ejecuta DENTRO del contenedor de InfluxDB (lo lanza ./deploy.sh
# influx-tokens) y usa las variables que el compose ya le pasa:
#   DOCKER_INFLUXDB_INIT_ADMIN_TOKEN, DOCKER_INFLUXDB_INIT_ORG
#
# InfluxDB 2.x no permite elegir el valor de un token: siempre lo genera
# él. Por eso los tokens se crean aquí y deploy.sh los copia al .env.
#
# Salida (stdout), una línea por token:
#   INFLUX_READ_TOKEN=...
#   INFLUX_WRITE_TOKEN=...
# Los mensajes de progreso van a stderr.
# ------------------------------------------------------------------
set -eu

READ_DESC="grafana-read"
WRITE_DESC="nodered-write"
# Nombres fijos: los usan también los dashboards, las alertas y Node-RED
DAILY_BUCKET="ventas_diarias"
MONTHLY_BUCKET="ventas_mensuales"

# Opciones comunes del CLI: siempre contra el servidor local y con el token de admin
INFLUX_OPTS="--host http://localhost:8086 --token $DOCKER_INFLUXDB_INIT_ADMIN_TOKEN"
ORG="$DOCKER_INFLUXDB_INIT_ORG"

log() { echo "$*" >&2; }

bucket_id() {
    # influx bucket list --hide-headers -> ID  Name  Retention ...
    # shellcheck disable=SC2086
    influx bucket list $INFLUX_OPTS --org "$ORG" --name "$1" --hide-headers | awk 'NR==1 {print $1}'
}

DAILY_ID=$(bucket_id "$DAILY_BUCKET")
MONTHLY_ID=$(bucket_id "$MONTHLY_BUCKET")
if [ -z "$DAILY_ID" ] || [ -z "$MONTHLY_ID" ]; then
    log "No se encuentran los buckets '$DAILY_BUCKET' y/o '$MONTHLY_BUCKET' en la org '$ORG'."
    exit 1
fi

# Borra los tokens creados en ejecuciones anteriores (misma descripción),
# para que volver a ejecutar el script no vaya acumulando tokens.
# influx auth list --hide-headers -> ID  Description  Token  User ...
# shellcheck disable=SC2086
influx auth list $INFLUX_OPTS --org "$ORG" --hide-headers \
    | awk -v r="$READ_DESC" -v w="$WRITE_DESC" '$2 == r || $2 == w {print $1}' \
    | while read -r old_id; do
        log "Borrando token anterior $old_id"
        # shellcheck disable=SC2086
        influx auth delete $INFLUX_OPTS --id "$old_id" >/dev/null
    done

create_token() {
    # $1 = descripción, $2 = read|write
    # influx auth create --hide-headers -> ID  Description  Token  User ...
    # shellcheck disable=SC2086
    influx auth create $INFLUX_OPTS --org "$ORG" --description "$1" \
        "--$2-bucket" "$DAILY_ID" "--$2-bucket" "$MONTHLY_ID" \
        --hide-headers | awk 'NR==1 {print $3}'
}

log "Creando token de lectura ($READ_DESC)"
READ_TOKEN=$(create_token "$READ_DESC" read)
log "Creando token de escritura ($WRITE_DESC)"
WRITE_TOKEN=$(create_token "$WRITE_DESC" write)

if [ -z "$READ_TOKEN" ] || [ -z "$WRITE_TOKEN" ]; then
    log "InfluxDB no devolvió alguno de los tokens."
    exit 1
fi

echo "INFLUX_READ_TOKEN=$READ_TOKEN"
echo "INFLUX_WRITE_TOKEN=$WRITE_TOKEN"
