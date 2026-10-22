#!/bin/sh
# ------------------------------------------------------------------
# init-flows.sh - Inyecta el token de escritura de InfluxDB en el
# nodo de configuracion de Node-RED antes de arrancar el runtime.
#
# El token llega por la variable INFLUX_WRITE_TOKEN (definida en el
# .env y pasada al contenedor por docker-compose.yml). Solo se
# modifica el campo "credentials.token" del nodo "influxdb": el
# resto del flujo (incluidos los cambios hechos en el editor) se
# respeta intacto.
#
# Es necesario porque Node-RED cifra las credenciales por
# instalacion: no se pueden versionar en flows.json.
# ------------------------------------------------------------------
set -e

FLUJOS=/data/flows.json

if [ -z "${INFLUX_WRITE_TOKEN}" ]; then
    echo "[init-flows] AVISO: INFLUX_WRITE_TOKEN no esta definido. El nodo de InfluxDB se quedara sin token."
elif [ ! -f "$FLUJOS" ]; then
    echo "[init-flows] AVISO: no se encuentra $FLUJOS"
else
    INFLUX_WRITE_TOKEN="$INFLUX_WRITE_TOKEN" FLUJOS="$FLUJOS" node -e '
        const fs = require("fs");
        const file = process.env.FLUJOS;
        const flows = JSON.parse(fs.readFileSync(file, "utf8"));
        let n = 0;
        for (const flow of flows) {
            if (flow.type === "influxdb") {
                flow.credentials = flow.credentials || {};
                flow.credentials.token = process.env.INFLUX_WRITE_TOKEN;
                n++;
            }
        }
        fs.writeFileSync(file, JSON.stringify(flows, null, 4) + "\n");
        console.log(`[init-flows] token de InfluxDB actualizado en ${n} nodo(s) de configuracion`);
    '
fi

exec /usr/src/node-red/entrypoint.sh "$@"
