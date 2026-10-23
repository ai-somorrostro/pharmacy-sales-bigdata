# Pharmacy Sales Big Data

Plataforma para el análisis y monitorización de ventas de una cadena de 120 farmacias en 8 países europeos. Combina **SBD**, **BDA** y **MIA** para ingestar, almacenar, visualizar y predecir datos de ventas.

## Stack

| Componente | Uso |
|---|---|
| **InfluxDB 2.7** | Almacén de series temporales |
| **Grafana 11.2** | Dashboards, alertas y aprovisionamiento |
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
# Editar .env con credenciales, tokens y configuración SMTP
```

### Despliegue
```bash
./deploy.sh up      # Levantar todos los servicios
./deploy.sh down    # Parar servicios (conserva volúmenes)
./deploy.sh clean   # Eliminar contenedores, redes y volúmenes
```

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
2. **Levantar stack**: `./deploy.sh up`
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
