ARG NODERED_VERSION
FROM nodered/node-red:${NODERED_VERSION}

ARG INFLUX_NODE_VERSION
RUN npm install --no-audit --no-fund --omit=dev node-red-contrib-influxdb@${INFLUX_NODE_VERSION}

# flows.json no se copia en la imagen: /data es un volumen y la copia solo se
# usaría la primera vez. docker-compose.yml lo monta en /opt/flows/flows.json
# e init-flows.sh lo copia a /data en cada arranque.

# Script de arranque: copia el flujo del repo y prepara el token de InfluxDB
COPY --chown=node-red:root init-flows.sh /opt/init-flows.sh
RUN chmod +x /opt/init-flows.sh
