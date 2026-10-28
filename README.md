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
# Editar .env: contraseñas, INFLUX_ADMIN_TOKEN y SMTP.
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

## Licencia

Código con fines académicos. Dataset *European Pharmacy Sales* (Kaggle) bajo **licencia MIT**. Componentes de terceros con sus respectivas licencias.
