# pharmacy-sales-bigdata

> **Reto 0 · Sistemas de Big Data (SBD)** — Análisis, almacenamiento en InfluxDB y monitorización de ventas de farmacias europeas.

Cadena de datos completa para una cadena de 120 farmacias en 8 países europeos: desde el dataset original en Excel, pasando por exploración y preparación en Jupyter, carga automatizada en Node-RED hacia InfluxDB, hasta la monitorización con dashboards y alertas de Grafana, accesible además vía MCP para asistentes de IA.

| | |
|---|---|
| **Dataset** | European Pharmacy Sales (Kaggle, licencia MIT) |
| **Stack** | InfluxDB 2.7 · Grafana 11.2 · Node-RED 4.0 · Python 3.12 / Jupyter · Docker Compose |
| **Volumen** | 62.139 ventas (2024-2025) · 120 farmacias · 220 productos · 8 países |
| **Autor** | Aimar Mora |

---

## Índice

1. [Contexto y problema](#1-contexto-y-problema)
2. [Objetivos y preguntas de negocio](#2-objetivos-y-preguntas-de-negocio)
3. [Arquitectura](#3-arquitectura)
4. [Stack tecnológico](#4-stack-tecnológico)
5. [Estructura del repositorio](#5-estructura-del-repositorio)
6. [Modelo de datos](#6-modelo-de-datos)
7. [Pipeline de datos (ETL)](#7-pipeline-de-datos-etl)
8. [Puesta en marcha](#8-puesta-en-marcha)
9. [Servicios, puertos y credenciales](#9-servicios-puertos-y-credenciales)
10. [Dashboards de Grafana](#10-dashboards-de-grafana)
11. [Alertas](#11-alertas)
12. [MCP de Grafana (integración con opencode)](#12-mcp-de-grafana-integración-con-opencode)
13. [Notebooks](#13-notebooks)
14. [Documentación entregable](#14-documentación-entregable)
15. [Resultados y conclusiones](#15-resultados-y-conclusiones)
16. [Notas y limitaciones conocidas](#16-notas-y-limitaciones-conocidas)
17. [Solución de problemas](#17-solución-de-problemas)
18. [Licencia y créditos](#18-licencia-y-créditos)

---

## 1. Contexto y problema

El cliente es una **cadena de 120 farmacias en ocho países europeos** (Austria, Bélgica, Alemania, Países Bajos, Polonia, …) que quiere decidir **qué vender, dónde y si compensa promocionar**.

Disponía de 62.139 ventas de 2024-2025 con unidades, ingresos, coste, margen y marca de promoción, unidas a los catálogos de farmacias y productos y a un calendario. **No tiene** datos de clientes, de stock ni de la competencia.

El reto no es el análisis puntual: es **operar el dato de forma continua**. De ahí las tres capas del proyecto:

| Capa | Entregable | Herramienta |
|---|---|---|
| **SBD** (Sistema de Big Data) | Informe descriptivo con conclusiones de negocio | Jupyter + pandas |
| **BDA** (Big Data Analytics) | Plataforma de ingesta, almacén y monitorización | InfluxDB + Node-RED + Grafana |
| **MIA** (Modelos de IA) | Propuesta de IA para predecir margen por combinación | Gradient boosting vs. alternativas |

---

## 2. Objetivos y preguntas de negocio

El análisis descriptivo responde tres preguntas, que después se convertirán en KPIs monitorizados:

1. **¿Qué países y categorías generan más ingresos y mejor margen?**
2. **¿Cómo evolucionan las ventas mes a mes y hay estacionalidad?**
3. **¿Las promociones aumentan las unidades vendidas o solo reducen el margen?**

Y tres objetivos de plataforma:

4. **Automatizar la ingesta** desde el CSV hacia la base de datos temporal.
5. **Monitorizar** los indicadores con dashboards y alertas automáticas.
6. **Consultar** los datos de forma conversacional mediante un servidor MCP.

---

## 3. Arquitectura

```
                     ┌──────────────────────────────────────────────┐
                     │  Data/Pharmacy_data.xlsx  (Kaggle, MIT)      │
                     │  FactSales · DimDate · DimPharmacy · DimProduct│
                     └───────────────────────┬──────────────────────┘
                                             │
                        ┌────────────────────▼─────────────────────┐
                        │  notebook/01_exploracion.ipynb            │
                        │  EDA + join de las 4 hojas + conclusiones  │
                        └───────────────────────┬─────────────────────┘
                                             │
                        ┌────────────────────▼─────────────────────┐
                        │  BDA/preparar_datos_influxdb.ipynb        │
                        │  agregado diario y mensual + CSV         │
                        └───────┬──────────────────────┬────────────┘
                                │                      │
                   ventas_diarias.csv         ventas_mensuales.csv
                   ventas_simuladas.csv
                                │                      │
        ┌───────────────────────▼──────────────────────▼────────────┐
        │  Node-RED  (BDA/nodered)                                  │
        │  file in → csv → function (a puntos de InfluxDB) → batch │
        └───────────────────────┬────────────────────────────────────┘
                                │  measurement "ventas"
        ┌───────────────────────▼────────────────────────────────────┐
        │  InfluxDB 2.7                                            │
        │  buckets: ventas_diarias · ventas_mensuales               │
        └───────┬───────────────────────────────┬──────────────────┘
                │ Flux (datasource ds-influx)    │ API /mcp
        ┌───────▼──────────────┐        ┌───────▼──────────────────┐
        │  Grafana 11.2        │        │  MCP Grafana             │
        │  4 dashboards        │        │  (streamable-http :8000) │
        │  3 reglas de alerta  │        │  → opencode / Claude     │
        └──────────────────────┘        └──────────────────────────┘
```

**Modelo de datos en InfluxDB** (medición única `ventas`):

```
time      = Fecha (UTC)                    → timestamp
tags      = Country, Category, PromoFlag   → etiquetas (filtro/agrupación)
fields    = ventas, unidades,              → valores numéricos
            ingresos_eur, costes_eur,
            margen_eur
```

---

## 4. Stack tecnológico

| Componente | Versión | Papel |
|---|---|---|
| **InfluxDB** | 2.7.10 | Almacén de series temporales (buckets diario y mensual) |
| **Grafana** | 11.2.0 | Dashboards, aprovisionamiento y alertas |
| **Node-RED** | 4.0.2 | Ingesta y carga automatizada de CSV en InfluxDB |
| **node-red-contrib-influxdb** | 3.1.5 | Nodo de escritura (línea de comandos de InfluxDB) |
| **MCP Grafana** | imagen `grafana/mcp-grafana` | Servidor MCP de solo lectura sobre Grafana |
| **Python** | 3.12 | pandas / numpy / matplotlib / seaborn / openpyxl |
| **Jupyter** | Notebook 7 / Lab 4 | Exploración y preparación de datos |
| **Docker Compose** | v2 | Orquestación de los 4 servicios |

Todas las versiones de imagen están **fijadas** en `.env` para que el despliegue sea reproducible.

---

## 5. Estructura del repositorio

```
.
├── Data/
│   └── Pharmacy_data.xlsx            # Dataset original (solo en la rama main)
├── notebook/
│   └── 01_exploracion.ipynb         # EDA, joins y conclusiones (SBD)
├── BDA/                              # Capa de Big Data Analytics
│   ├── preparar_datos_influxdb.ipynb # Agregación diaria/mensual + export CSV
│   ├── ventas_diarias.csv            # Agregado diario  → bucket ventas_diarias
│   ├── ventas_mensuales.csv          # Agregado mensual → bucket ventas_mensuales
│   ├── ventas_simuladas.csv          # Proyección 2026 con anomalías (demo de alertas)
│   ├── BDA_AimarMora.pdf             # Documentación de la BDA
│   ├── influxdb/
│   │   └── init-buckets.sh           # Creación del bucket mensual al arrancar
│   ├── nodered/
│   │   ├── Dockerfile                # Node-RED + nodo InfluxDB + flows.json
│   │   └── flows.json                # 3 flujos: diario, mensual y simuladas
│   └── grafana/
│       ├── dashboards/               # 4 dashboards (formato Kubernetes CRD)
│       │   ├── evolucion_mensual.json
│       │   ├── paises_y_categorias.json
│       │   ├── promociones.json
│       │   └── rentabilidad_y_crecimiento.json
│       └── provisioning/
│           ├── dashboards/dashboard.yml     # Proveedor de dashboards
│           ├── datasources/influxdb.yml     # Datasource "ds-influx" (Flux)
│           └── alerting/
│               ├── contact-points.json      # Receptor de email
│               ├── policies.json            # Política de notificación
│               └── rules.json               # 3 reglas de alerta
├── SBD/
│   └── Informe_cliente_farmacia.docx # Informe de análisis para el cliente
├── MIA/
│   └── MIA_farmacia.docx             # Propuesta de solución de IA
├── docker-compose.yml                # InfluxDB + Grafana + Node-RED + MCP
├── deploy.sh                         # up / down / clean
├── .env.example                      # Plantilla de configuración
├── requirements.txt                  # Dependencias Python
├── opencode.json                     # Configuración del servidor MCP
└── README.md
```

---

## 6. Modelo de datos

### 6.1 Origen: esquema en estrella

El Excel contiene cuatro hojas que se unen por claves:

| Hoja | Filas | Rol | Clave |
|---|---|---|---|
| `FactSales` | 62.139 | Hechos: `UnitsSold`, `RevenueEUR`, `CostEUR`, `MarginEUR`, `PromoFlag` | `SalesID`, `DateKey`, `PharmacyID`, `ProductID` |
| `DimDate` | 731 | Calendario (2024-2025) | `DateKey` (`YYYYMMDD`) |
| `DimPharmacy` | 120 | Farmacias: `Country`, `PharmacyType`, `StoreSizeBand`, `OpenDate` | `PharmacyID` |
| `DimProduct` | 220 | Productos: `Category`, `IsGeneric`, `IsDiscontinued`, precios | `ProductID` |

Dimensión `Category`: `Prescription`, `OTC`, `Wellness`, `Personal Care`, `Medical Devices`.
Dimensión `PromoFlag`: `Yes` / `No`.

### 6.2 Sello temporal (star schema temporal)

```python
data = (
    fact
    .merge(fecha,   on="DateKey",    how="left", validate="many_to_one")
    .merge(farmacia,on="PharmacyID", how="left", validate="many_to_one")
    .merge(producto,on="ProductID",  how="left", validate="many_to_one")
)
data["Fecha"] = pd.to_datetime(data["DateKey"].astype(str), format="%Y%m%d")
```

### 6.3 Agregación previa a la carga (clave del diseño)

En InfluxDB, **dos puntos con la misma medición + tags + timestamp se sobrescriben**. Como las ventas se repiten mucho para un mismo día/país/categoría/promoción, se **agrega antes de escribir**:

```python
columnas_tag = ["Country", "Category", "PromoFlag"]

diario = data.groupby(["Fecha"] + columnas_tag, as_index=False).agg(
    ventas=("SalesID","count"), unidades=("UnitsSold","sum"),
    ingresos_eur=("RevenueEUR","sum"), costes_eur=("CostEUR","sum"),
    margen_eur=("MarginEUR","sum"))
```

El agregado mensual es idéntico, pero con la fecha en el **primer día de cada mes** y bucketing en `ventas_mensuales`.

### 6.4 CSV generados

Ambos CSV comparten este esquema (una fila = un punto de InfluxDB):

```csv
Fecha,Country,Category,PromoFlag,ventas,unidades,ingresos_eur,costes_eur,margen_eur
2024-01-01 00:00:00+00:00,Austria,Medical Devices,No,1,1,24.78,17.38,7.4
2024-01-01 00:00:00+00:00,Austria,OTC,No,5,58,522.57,378.83,143.74
```

### 6.5 Dataset simulado (para probar alertas)

`ventas_simuladas.csv` proyecta 2025 a 2026 e inyecta anomalías deliberadas:

1. Ruido coherente: factor `N(0, 10 %)` por fila, aplicado igual a las cuatro columnas de volumen.
2. **Anomalía de volumen**: racha de 16 días (2026-09-10 → 2026-09-25) con **-40 %** de ventas.
3. **Anomalía de margen**: 10 días (2026-08-01 → 2026-08-10) con ingresos **-15 %** y mismo coste.

Sirve para comprobar que las alertas y los umbrales reaccionan a eventos reales.

---

## 7. Pipeline de datos (ETL)

```
EXTRACT ──────────────► TRANSFORM ──────────────► LOAD ──────────────► SERVE
Excel (4 hojas)         joins + tipado + fechas    Node-RED             Grafana
                        agregado diario/mensual    → InfluxDB           + MCP
                        + simulación 2026          (measurement         + alertas
                                                    "ventas")
```

### 7.1 `notebook/01_exploracion.ipynb` — Análisis (SBD)

1. **Adquisición**: `pd.read_excel(..., sheet_name=None)` (las cuatro hojas caben en memoria).
2. **Exploración**: `describe()`, asimetría, histogramas, `value_counts()`, nulos y duplicados por hoja.
3. **Integración**: join de las 4 tablas con `validate="many_to_one"` y parseo de fechas.
4. **Control de calidad**: ventas anteriores a `OpenDate` y posteriores a `DiscontinuedDate`.
5. **Análisis**: las tres preguntas de negocio con sus tablas y gráficos.
6. **Conclusiones** en markdown, lista para el informe al cliente.

### 7.2 `BDA/preparar_datos_influxdb.ipynb` — Preparación (BDA)

Siete pasos guiados, con comprobaciones en cada uno:

| Paso | Acción | Verificación |
|---|---|---|
| 1 | Cargar y unir hojas | `merge` con validación |
| 2 | Crear `Fecha` en UTC | `tz_localize("UTC")` |
| 3 | Agregar por día | clave única |
| 4 | Agregar por mes | fecha = día 1 del mes |
| 5 | Generar datos simulados 2026 | sin márgenes negativos |
| 6 | **Comprobar** | duplicados = 0, ingresos diario = mensual = original, nulos = 0 |
| 7 | Guardar CSV | `ventas_diarias.csv`, `ventas_mensuales.csv` |

> Si las comprobaciones del paso 6 no cuadran, el proceso **no debe continuar**: revisar los pasos anteriores.

### 7.3 Node-RED — Ingesta (BDA)

`BDA/nodered/flows.json` contiene **tres flujos** (uno por CSV). Todos comparten la misma cadena:

```
[file in] → [csv] → [function "a puntos de InfluxDB"] → [influxdb batch]
```

- **`file in`**: lee el CSV en modo UTF-8.
- **`csv`**: separa por `,` y salta la cabecera.
- **`function`**: convierte cada fila en un punto de InfluxDB con `measurement`, `tags`, `fields` y `timestamp`; los flujos diario y mensual **envían en lotes de 5.000 puntos** (`CHUNK = 5000`) para no saturar la memoria; el flujo de simuladas valida cada fila y descarta las inválidas con `node.warn`.
- **`influxdb batch`**: escribe en el bucket correspondiente (`ventas_diarias` / `ventas_mensuales`) dentro de la organización configurada.

Los flujos se activan manualmente desde el botón *Inject* de Node-RED.

### 7.4 Almacenamiento — InfluxDB

- Bucket **diario**: `ventas_diarias` (retención infinita).
- Bucket **mensual**: `ventas_mensuales`, creado automáticamente por `BDA/influxdb/init-buckets.sh` en el arranque del contenedor (`/docker-entrypoint-initdb.d/`).
- Todos los buckets se crean con `DOCKER_INFLUXDB_INIT_*` o con el script de inicialización, de modo que el entorno queda reproducible desde cero.

---

## 8. Puesta en marcha

### 8.1 Requisitos

- Docker y Docker Compose **v2** (`docker compose version`).
- Python 3.12 + Jupyter, solo para los notebooks.
- El dataset `Data/Pharmacy_data.xlsx` (disponible en la rama `main` del repositorio o en Kaggle).

### 8.2 Instalación de las dependencias de Python

```bash
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 8.3 Configuración del entorno

```bash
cp .env.example .env
```

Edita `.env` y sustituye **todos** los valores de ejemplo por los reales. Variables **obligatorias**:

| Grupo | Variables |
|---|---|
| Versiones | `INFLUXDB_VERSION`, `GRAFANA_VERSION`, `NODERED_VERSION`, `NODERED_INFLUX_NODE_VERSION`, `GRAFANA_MCP_VERSION` |
| InfluxDB | `INFLUX_ADMIN_USER`, `INFLUX_ADMIN_PASSWORD`, `INFLUX_ORG`, `INFLUX_ADMIN_TOKEN`, `INFLUX_READ_TOKEN`, `INFLUX_WRITE_TOKEN`, `INFLUX_BUCKET_DAILY`, `INFLUX_BUCKET_MONTHLY` |
| Grafana | `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD` |
| MCP Grafana | `GRAFANA_MCP_TOKEN` (token de *service account*), `GRAFANA_MCP_PORT` |
| Alertas por email | `SMTP_USER`, `SMTP_PASSWORD` |
| Rutas | `DATA_DIR` (por defecto `./BDA`) |

> `docker-compose.yml` valida las variables con `:?`, por lo que **el entorno no arranca si falta cualquiera de ellas**.

### 8.4 Despliegue

El script `deploy.sh` es el punto de entrada único:

```bash
./deploy.sh up      # construye y levanta todo en segundo plano
./deploy.sh down    # para los contenedores (conserva los datos)
./deploy.sh clean   # borra contenedores, redes y volúmenes (pide confirmación)
./deploy.sh clean -y   # sin confirmación
```

`up` comprueba antes que Docker está instalado, que Compose v2 está disponible, que el daemon responde y que existe `.env` (copiando `.env.example` si falta).

### 8.5 Ejecución del pipeline

```bash
# 1) Generar los CSV (o abrir el notebook en Jupyter)
jupyter lab

# 2) Levantar la plataforma
./deploy.sh up

# 3) Cargar los datos: abrir http://127.0.0.1:1881 y pulsar "Inject"
#    en cada uno de los tres flujos
```

---

## 9. Servicios, puertos y credenciales

Todos los puertos se publican **solo en `127.0.0.1`** (no accesibles desde la red).

| Servicio | URL local | Puerto host → contenedor | Credenciales |
|---|---|---|---|
| InfluxDB | http://127.0.0.1:8087 | `8087 → 8086` | `INFLUX_ADMIN_USER` / `INFLUX_ADMIN_PASSWORD` + token |
| Grafana | http://127.0.0.1:3000 | `3000 → 3000` | `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` |
| Node-RED | http://127.0.0.1:1881 | `1881 → 1880` | sin autenticación (solo local) |
| MCP Grafana | http://127.0.0.1:8000/mcp | `8000 → 8000` | `Bearer GRAFANA_MCP_TOKEN` |

---

## 10. Dashboards de Grafana

El aprovisionamiento monta `BDA/grafana/provisioning` (datasource, dashboards y alertas) y `BDA/grafana/dashboards` (los JSON), con actualización cada 10 s. El datasource se llama **`ds-influx`** (Flux) y es el predeterminado.

| Dashboard | Paneles | Pregunta que responde |
|---|---|---|
| **Evolución mensual** | Ingreso mensual 2024-2025 · Ingreso total por año · Tabla de ingresos mensuales | ¿Cómo evolucionan las ventas? ¿Hay estacionalidad? |
| **Países y categorías** | Ingresos totales por país · % de ingresos por categoría · Beneficio por categoría | ¿Dónde y qué vender? |
| **Promociones** | Margen con y sin promoción · Margen en ventas con promoción | ¿Las promociones compensan? |
| **Rentabilidad y Crecimiento en Farmacias** | Crecimiento de ingresos por país (2025 vs 2024) · Crecimiento por categoría · Margen cedido por promociones | ¿Dónde está creciendo y cuánto margen regala el precio? |

Las consultas están escritas en **Flux** sobre la medición `ventas` de los buckets `ventas_diarias` y `ventas_mensuales`.

---

## 11. Alertas

Las tres reglas se aprovisionan desde `BDA/grafana/provisioning/alerting/`, se evalúan **cada minuto** y notifican por email al *contact point* configurado.

| Regla | Cálculo (Flux) | Condición de disparo |
|---|---|---|
| **Margen % en promoción** | `margen_eur / ingresos_eur * 100` sobre las ventas con `PromoFlag = "Yes"` | `> 0` |
| **Ingresos del mes anterior por debajo del objetivo** | suma de `ingresos_eur` del mes natural anterior | `< 350.000 €` |
| **Crecimiento de ingresos negativo por país** | variación 2025 vs 2024 de `ingresos_eur`, agrupado por `Country` | `< 0 %` |

- **Contact point**: receptor de email (Grafana → *Alerting → Contact points*).
- **Política**: agrupación por `grafana_folder` y `alertname`.
- Estados ante falta de datos o error: `NoData` / `Error`.

> Para que el email llegue, `SMTP_USER` y `SMTP_PASSWORD` deben ser válidos y la cuenta debe permitir el acceso SMTP (en Gmail, «app password»).

> ⚠️ La regla **«Margen % en promoción»** tiene un umbral permisivo (`> 0`): con el margen real de las promociones (~19,9 %) la alerta queda permanentemente activa. Conviene subir el umbral (por ejemplo `> 20`, o disparar por debajo de un mínimo como `< 15 %`) para que signififique algo.

---

## 12. MCP de Grafana (integración con opencode)

El servicio `mcp-grafana` expone Grafana mediante **Model Context Protocol** sobre `streamable-http`, en **modo solo lectura** (`--disable-write`), lo que permite consultar dashboards, paneles y métricas desde un asistente de IA.

```yaml
# opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "mcp-grafana": {
      "type": "remote",
      "url": "http://localhost:8000/mcp",
      "enabled": true,
      "headers": {
        "Authorization": "Bearer {env:MCP_GRAFANA_SERVER_TOKEN}"
      }
    }
  }
}
```

Para usarlo:

1. Exporta el token como variable de entorno: `export MCP_GRAFANA_SERVER_TOKEN=<GRAFANA_MCP_TOKEN>`.
2. Comprueba que el contenedor está vivo: `curl http://127.0.0.1:8000/mcp`.
3. Abre opencode en la raíz del proyecto: la configuración de `opencode.json` se carga automáticamente.

---

## 13. Notebooks

### `notebook/01_exploracion.ipynb` — Análisis exploratorio y conclusiones

Estructurado en seis secciones: análisis del problema, adquisición, exploración (numéricas, categóricas, calidad y nulos), join de las cuatro hojas, las tres preguntas de negocio y las conclusiones. Cada respuesta termina en un bloque de *markdown* con la interpretación y la recomendación accionable.

### `BDA/preparar_datos_influxdb.ipynb` — Preparación para InfluxDB

Guía paso a paso pensada para no cometerse el error clásico de InfluxDB (puntos que se sobrescriben): explica el roles de `time`, `tags` y `fields`, agrega antes de escribir, incluye un dataset simulado con anomalías y termina con **tres comprobaciones obligatorias** (duplicados = 0, totales de ingresos iguales a los originales, nulos = 0).

---

## 14. Documentación entregable

| Documento | Ruta | Contenido |
|---|---|---|
| **SBD** — Informe para el cliente | `SBD/Informe_cliente_farmacia.docx` | Análisis de ventas de retail farmacético en Europa, con las tres preguntas de negocio y recomendaciones. |
| **BDA** — Documentación de la plataforma | `BDA/BDA_AimarMora.pdf` | Arquitectura, modelo de datos, ingesta, dashboards, alertas y MCP. |
| **MIA** — Modelos de IA | `MIA/MIA_farmacia.docx` | Propuesta de IA: requisitos R1-R6, comparación de modelos (regresión lineal, series temporales, Random Forest, Gradient Boosting, LSTM), modelo seleccionado, diagrama de funcionamiento, impacto, ventajas, limitaciones y riesgos. |

---

## 15. Resultados y conclusiones

### Países y categorías

- El **margen porcentual apenas varía entre países** (27,8 % - 28,2 %): las diferencias vienen del **volumen por farmacia**, no de la rentabilidad de cada venta.
- Corrigiendo por meses de actividad, lideran **Bélgica (3.732 € por farmacia-mes)** y **Países Bajos (3.673 €)**; **Polonia** es última (2.289 € por farmacia-mes), un 39 % por debajo de Bélgica, y no tiene farmacias abiertas en 2025.
- **Alemania** lidera en margen total (439 k€) solo por tener más farmacias (22).
- La brecha se explica sobre todo por el **ticket medio** (107,5 € en Polonia frente a 154,4 € en Países Bajos).
- **Prescription** aporta el mayor margen en euros (613 k€) con el margen % más bajo (21,9 %): 32,4 % de los ingresos y 25,3 % del margen. **Wellness** (33,6 %) y **Personal Care** (33,5 %) suman el 36,6 % de los ingresos pero el **43,9 % del margen**.

### Evolución mensual y estacionalidad

- Los ingresos pasan de **4,22 M€ (2024) a 4,41 M€ (2025), +4,4 %**; 2025 supera a 2024 en 9 de los 12 meses.
- El crecimiento se concentra **a partir de abril** (hasta +12,9 % en diciembre).
- **No hay estacionalidad estable**: el mes más alto cambia (julio en 2024, mayo en 2025) y solo febrero es el más bajo en ambos años.
- **Recomendación**: no planificar stock con un patrón estacional fijo y verificar si el +4,4 % viene de farmacias nuevas o de más ventas por farmacia.

### Efecto de las promociones

- Las promociones **no aumentan las unidades por venta** (7,02 frente a 7,19) y **reducen el margen del 29,0 % al 19,9 %**.
- El mecanismo es un **descuento de precio**: el ingreso por unidad cae un 11 % (19,62 € → 17,46 €) mientras el coste por unidad no cambia; el margen por unidad cae un 39 % (5,69 € → 3,48 €).
- Las ventas en promoción son el **12,0 %** del total pero aportan solo el **7,5 %** del margen. En **Prescription** el margen en promoción baja al **13,8 %**, el más bajo de todas las categorías.
- **Recomendación**: reducir o rediseñar las promociones empezando por Prescription; compensar el margen por unidad exigiría vender un **63 % más** de unidades, y los datos no muestran ningún aumento.

---

## 16. Notas y limitaciones conocidas

- **Rutas de los CSV en Node-RED**: `flows.json` guarda rutas absolutas del host WSL (`/mnt/c/clase/...`). Dentro del contenedor los CSV se montan en **`/csv`** (`${DATA_DIR:-./BDA}:/csv:ro`), por lo que hay que **actualizar la ruta de los nodos `file in`** a `/csv/ventas_diarias.csv`, `/csv/ventas_mensuales.csv` y `/csv/ventas_simuladas.csv`.
- **Variables de entorno**: `.env.example` no incluye todavía `GRAFANA_MCP_VERSION`, `GRAFANA_MCP_TOKEN`, `GRAFANA_MCP_PORT`, `SMTP_USER` ni `SMTP_PASSWORD`, que `docker-compose.yml` exige. Se deben añadir manualmente (o completar la plantilla).
- **Puerto de InfluxDB**: se publica en `8087` (no en `8086`) para no chocar con el puerto por defecto de InfluxDB en el host; la variable `INFLUX_PORT` del `.env` no interviene en el `docker-compose.yml`.
- **`.env` está en `.gitignore`**: nunca subas tokens ni contraseñas al repositorio.
- **CSV generados no se versionan**: el `.gitignore` excluye `*.csv`; las versiones que hay en `BDA/` están añadidas de forma explícita para poder versionar los datos de partida.
- **Limitación analítica**: no hay datos de clientes, de stock, de tráfico ni de competencia; el análisis de promociones mide unidades por venta, no número de clientes atraídos.
- **Datos simulados**: `ventas_simuladas.csv` es una proyección estadística, no información real; sirve para validar alertas y automatismos.

---

## 17. Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `ERROR: variable is not set. ...` al hacer `docker compose up` | falta una variable obligatoria en `.env` | revisa la lista de la §8.3; `docker compose config` muestra las que faltan |
| `the name "..." was not found` / `no such bucket` | el bucket mensual no se creó | comprueba `docker compose logs influxdb` y que `BDA/influxdb/init-buckets.sh` está montado en `/docker-entrypoint-initdb.d/` |
| Los dashboards salen vacíos | no se han cargado los CSV o el rango de tiempo no cubre los datos | pulsa *Inject* en los flujos de Node-RED y ajusta el rango temporal del panel |
| No llegan los emails de alerta | SMTP mal configurado o cuenta sin *app password* | revisa `SMTP_USER`/`SMTP_PASSWORD` y la política de Grafana |
| El MCP no responde | token incorrecto o contenedor caído | `docker compose logs mcp-grafana` y `curl http://127.0.0.1:8000/mcp` |
| Node-RED no encuentra el CSV | rutas absolutas del host en `flows.json` | cambia la ruta del nodo `file in` a `/csv/<fichero>.csv` (§16) |
| Cambié las variables y no se aplican | hay que recrear los contenedores | `./deploy.sh down && ./deploy.sh up` |

---

## 18. Licencia y créditos

- **Código del proyecto**: uso académico (asignatura SBD / Reto 0).
- **Dataset**: *European Pharmacy Sales* de Kaggle, **licencia MIT**. Los ficheros generados (`ventas_*.csv`) derivan de él y heredan la misma licencia.
- **Componentes de terceros**: InfluxDB (MIT), Grafana (AGPL-3.0), Node-RED (Apache-2.0), `node-red-contrib-influxdb` (MIT), `grafana/mcp-grafana` (Apache-2.0).
