ARG NODERED_VERSION
FROM nodered/node-red:${NODERED_VERSION}

ARG INFLUX_NODE_VERSION
RUN npm install --no-audit --no-fund --omit=dev node-red-contrib-influxdb@${INFLUX_NODE_VERSION}

# Flujos exportados desde Node-RED (menú > Exportar > todos los flujos)
COPY --chown=node-red:root flows.json /data/flows.json
