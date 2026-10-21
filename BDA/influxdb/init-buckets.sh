#!/bin/sh
set -e
influx bucket create --name "$INFLUX_BUCKET_MONTHLY" \
  --org "$DOCKER_INFLUXDB_INIT_ORG" --retention 0