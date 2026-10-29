#!/bin/sh
# ------------------------------------------------------------------
# init-flows.sh - Prepara los flujos de Node-RED antes de arrancar.
#
# 1) El repositorio manda: copia BDA/nodered/flows.json (montado en
#    /opt/flows/flows.json) sobre /data/flows.json en cada arranque.
#    Así los cambios del repo llegan al contenedor sin borrar el
#    volumen. Lo que se cambie en el editor de Node-RED hay que
#    exportarlo a BDA/nodered/flows.json o se pierde al reiniciar.
#
# 2) Escribe /data/flows_cred.json con el token de los nodos de
#    configuración de InfluxDB. Node-RED solo lee las credenciales
#    de ese fichero (las que hubiera dentro de flows.json las ignora
#    al arrancar). Se guarda el texto literal ${INFLUX_WRITE_TOKEN}:
#    Node-RED lo sustituye por la variable de entorno al cargar el
#    nodo, de modo que el token real nunca se escribe en el volumen.
#
# Por el mismo mecanismo, flows.json usa ${INFLUX_URL} e
# ${INFLUX_ORG}, que pasa docker-compose.yml.
# ------------------------------------------------------------------
set -e

ORIGEN=/opt/flows/flows.json
FLUJOS=/data/flows.json
CREDENCIALES=/data/flows_cred.json

if [ -f "$ORIGEN" ]; then
    cp "$ORIGEN" "$FLUJOS"
    echo "[init-flows] flows.json copiado desde el repositorio"
else
    echo "[init-flows] AVISO: no se encuentra $ORIGEN; se usa el flows.json del volumen"
fi

if [ -z "${INFLUX_WRITE_TOKEN:-}" ]; then
    echo "[init-flows] AVISO: INFLUX_WRITE_TOKEN está vacío. Ejecuta ./deploy.sh influx-tokens"
fi

if [ -f "$FLUJOS" ]; then
    FLUJOS="$FLUJOS" CREDENCIALES="$CREDENCIALES" node -e '
        const fs = require("fs");
        const flows = JSON.parse(fs.readFileSync(process.env.FLUJOS, "utf8"));
        const creds = {};
        for (const n of flows) {
            if (n.type === "influxdb") {
                // Texto literal: lo resuelve Node-RED con la variable de entorno
                creds[n.id] = { token: "${INFLUX_WRITE_TOKEN}" };
            }
        }
        fs.writeFileSync(process.env.CREDENCIALES, JSON.stringify(creds, null, 4) + "\n");
        console.log("[init-flows] token de InfluxDB asignado a " + Object.keys(creds).length + " nodo(s) de configuración");
    '
fi

exec /usr/src/node-red/entrypoint.sh "$@"
