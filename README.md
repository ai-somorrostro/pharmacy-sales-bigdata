# Pharmacy Sales Big Data

Plataforma para el análisis y monitorización de ventas de una cadena de 120 farmacias en 8 países europeos. Combina **SBD**, **BDA** y **MIA** para ingestar, almacenar, visualizar y predecir datos de ventas.

## Stack

| Componente | Uso |
|---|---|
| **InfluxDB 2.7** | Almacén de series temporales |
| **Grafana 13.2** | Dashboards, alertas y aprovisionamiento |
| **Node-RED 4.0** | Ingesta automatizada de CSV |
| **Docker Compose** | Orquestación de servicios |
| **Python 3.12 + Jupyter** | EDA y preparación de datos |
| **MCP Grafana** | Consultas conversacionales con IA |

## Docker

### Requisitos
- [Docker](https://www.docker.com/) y [Docker Compose v2](https://docs.docker.com/compose/)

### Configuración
```bash
cp .env.example .env
# Editar .env: contraseñas, INFLUX_ADMIN_TOKEN y SMTP (ALERT_EMAIL = destinatario
# de las alertas; vacío, se envían a SMTP_USER).
# Deja vacíos INFLUX_READ_TOKEN, INFLUX_WRITE_TOKEN, GRAFANA_MCP_TOKEN y
# MCP_GRAFANA_SERVER_TOKEN: se generan solos en el primer arranque.
```

### Despliegue
```bash
./deploy.sh up             # Levantar todos los servicios
./deploy.sh influx-tokens  # Crear los tokens de lectura/escritura de InfluxDB
./deploy.sh mcp-token      # Crear el service account del MCP y arrancarlo
./deploy.sh down           # Parar servicios (conserva volúmenes)
./deploy.sh clean          # Eliminar contenedores, redes y volúmenes
```

### Primer arranque

```bash
./deploy.sh up && ./deploy.sh influx-tokens && ./deploy.sh mcp-token
```

1. `up` levanta InfluxDB, Grafana y Node-RED. El MCP está en el *profile* `mcp` y no arranca hasta que tiene token.
2. `influx-tokens` crea en InfluxDB un token de lectura (Grafana) y otro de escritura (Node-RED), limitados a `ventas_diarias` y `ventas_mensuales`, los guarda en `.env` y reinicia esos servicios. InfluxDB no permite elegir el valor de un token, por eso no se pueden fijar de antemano.
3. `mcp-token` crea en Grafana el service account `mcp-grafana` (rol `GRAFANA_MCP_ROLE`), guarda su token en `GRAFANA_MCP_TOKEN`, genera `MCP_GRAFANA_SERVER_TOKEN` si falta, escribe `mcp-token.txt` para opencode y arranca el MCP.

Los tres se pueden repetir: crean tokens nuevos y sustituyen a los anteriores.

> A mano, el service account se crea en Grafana → *Administration → Users and access → Service accounts*, con rol *Viewer* y un token; se copia en `GRAFANA_MCP_TOKEN` y se arranca con `docker compose --profile mcp up -d mcp-grafana`.

### Servicios
| Servicio | URL | Puerto |
|---|---|---|
| **InfluxDB** | [http://127.0.0.1:8087](http://127.0.0.1:8087) | 8087 |
| **Grafana** | [http://127.0.0.1:3000](http://127.0.0.1:3000) | 3000 |
| **Node-RED** | [http://127.0.0.1:1881](http://127.0.0.1:1881) | 1881 |
| **MCP Grafana** | [http://127.0.0.1:8000/mcp](http://127.0.0.1:8000/mcp) | 8000 |

> Todo expuesto solo en `localhost`. Los volúmenes garantizan la persistencia de datos.

### Flujos de Node-RED

El repositorio manda: `BDA/nodered/flows.json` se monta en el contenedor y `init-flows.sh` lo copia sobre el del volumen en cada arranque. Para aplicar un cambio del repo basta con `docker compose restart nodered`.

- Lo que se cambie en el editor de Node-RED **se pierde al reiniciar** si no se exporta: *menú → Exportar → Todos los flujos* y guardar en `BDA/nodered/flows.json`.
- La URL y la organización de InfluxDB no están escritas en el flujo: los nodos usan `${INFLUX_URL}` y `${INFLUX_ORG}`, que pasa `docker-compose.yml`.
- El token tampoco: `init-flows.sh` escribe en `flows_cred.json` el texto `${INFLUX_WRITE_TOKEN}` y Node-RED lo sustituye por la variable de entorno al arrancar, así que no hay que escribirlo en el editor ni queda guardado en el volumen.

## Datos simulados

`ventas_simuladas.csv` copia las ventas diarias de 2025 al año 2026, con ruido y dos anomalías provocadas (una racha de 16 días con un 40 % menos de ventas y una bajada de precio de 10 días). **No son datos reales**: sirven para probar las alertas.

- Se escriben en el bucket `ventas_diarias`, junto a los reales, con fechas de 2026.
- Los dashboards consultan el rango 2024-01-01 → 2026-01-01, por lo que solo muestran datos reales.
- Las alertas usan rangos relativos (últimos 30 días, últimos 12 meses), por lo que evalúan los datos simulados.

> Si un dashboard pasa a usar un rango hasta `now`, incluirá los datos simulados en sus totales. Para evitarlo, termina el rango en `2026-01-01T00:00:00Z` o borra los simulados:
> ```bash
> docker compose exec influxdb influx delete --bucket ventas_diarias \
>   --start 2026-01-01T00:00:00Z --stop 2100-01-01T00:00:00Z
> ```

## Puesta en marcha rápida

1. **Preparar datos**: Ejecutar `BDA/preparar_datos_influxdb.ipynb` para generar los CSV.
2. **Levantar stack**: `./deploy.sh up` (la primera vez, también `influx-tokens` y `mcp-token`; ver *Primer arranque*)
3. **Ingestar**: Abrir [Node-RED](http://127.0.0.1:1881) e iniciar los flujos `diario`, `mensual` y `simuladas`.
4. **Visualizar**: Acceder a [Grafana](http://127.0.0.1:3000) con los dashboards preaprovisionados.

## Estructura

```text
├── Data/           # Dataset original
├── notebook/       # Exploración y EDA
├── BDA/            # Ingesta, Node-RED, Grafana, InfluxDB
├── SBD/            # Informe para el cliente
├── MIA/            # Propuesta de IA
├── docker-compose.yml
├── deploy.sh
└── .env.example
```

## Documentación entregable

| Módulo | Archivo |
|---|---|
| **SBD** | `SBD/Informe_cliente_farmacia.docx` |
| **BDA** | `BDA/BDA_AimarMora.pdf` |
| **MIA** | `MIA/MIA_farmacia.docx` |

## Limitaciones conocidas

- **`.env` está en `.gitignore`**: nunca subas tokens ni contraseñas al repositorio.
- **CSV generados no se versionan**: el `.gitignore` excluye `*.csv`; los de `BDA/` están añadidos de forma explícita para versionar los datos de partida.
- **Limitación analítica**: no hay datos de clientes, de stock, de tráfico ni de competencia; el análisis de promociones mide unidades por venta, no número de clientes atraídos.
- **Datos simulados**: ver la sección *Datos simulados*.

## Licencia

Código con fines académicos. Dataset *European Pharmacy Sales* (Kaggle) bajo **licencia MIT**. Componentes de terceros con sus respectivas licencias.

## Autores

- **Aimar Mora**
