# Flujo de trabajo con git

```
feature/* · fix/* · docs/*  ──PR──▶  develop  ──PR──▶  main
```

- **`main`**: solo versiones que funcionan. Recibe `develop` mediante PR cada vez que hay una versión estable, no solo al final.
- **`develop`**: integración. **Nunca se hace commit directo**, tampoco desde el editor web de GitHub.
- **Ramas de trabajo**: una por feature o arreglo, con nombre descriptivo:
  - `feature/...`: funcionalidad nueva (`feature/dashboard-promociones`)
  - `fix/...`: corrección (`fix/tokens-influxdb`)
  - `docs/...`: solo documentación, aunque sea un cambio pequeño del README (`docs/readme-arquitectura`)

## Ciclo de una rama

```bash
git switch develop
git pull origin develop                 # partir siempre de develop actualizado
git switch -c feature/nombre-descriptivo

# ... trabajar, con commits pequeños: un commit = un cambio,
#     y el mensaje dice lo que hace ese commit

git push -u origin feature/nombre-descriptivo
```

1. Abrir la PR hacia `develop`. La plantilla pide qué cambia, por qué y cómo se ha probado.
2. Revisarla antes de fusionar: leer el diff en *Files changed* y dejar un comentario con lo que se ha probado.
3. Fusionar y **cerrar la rama antes de empezar la siguiente**, para que no se cuelen commits de otra feature.

Al añadir ficheros, hazlo por nombre (`git add fichero`), no con `git add -A`, para no meter cambios ajenos a la PR.

## Pasar a `main`

Cuando `develop` funcione de principio a fin (`./deploy.sh up`, carga de datos y dashboards), abrir una PR `develop → main`.

## Antes de entregar

Comprobar que no queda nada sin integrar. Cada rama debe dar **0** (sin commits fuera de `main`):

```bash
# Bash / WSL
git fetch --all --prune
for b in $(git branch -r | grep -v HEAD); do echo "$b $(git rev-list --count origin/main..$b)"; done
```

```powershell
# PowerShell
git fetch --all --prune
git branch -r | Where-Object { $_ -notmatch 'HEAD' } | ForEach-Object { $b = $_.Trim(); "$b $(git rev-list --count origin/main..$b)" }
```

Si una rama da más de 0, o se integra con su PR o, si ya no hace falta, se borra.
