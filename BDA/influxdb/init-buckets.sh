#!/bin/sh
set -e
# El bucket diario lo crea el modo setup (DOCKER_INFLUXDB_INIT_BUCKET).
# Los nombres están fijos: los usan los dashboards, las alertas y Node-RED.
influx bucket create --name ventas_mensuales \
  --org "$DOCKER_INFLUXDB_INIT_ORG" --retention 0