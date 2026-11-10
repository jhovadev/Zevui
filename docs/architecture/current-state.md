# Zevui — Fase 0: estado actual (auditoría de solo lectura)

Fecha: 2026-11-10. Base: **`zevui-z0-registry-planner.zip`**, entrega Z0 anterior, 97 archivos de origen. **No es una lectura en vivo** de `~/Documents/sideProjects/zdata-dvui-examples`: ese directorio pertenece al equipo del desarrollador y no está montado en el entorno de auditoría. No se movió, eliminó ni modificó código de la base. `[verificado: listado e inspección del ZIP Z0]`

## Convención de evidencia

- **`[verificado: archivo/ruta]`**: inspección de contenido de la copia Z0 indicada. Acredita el estado del ZIP, no el árbol Git local.
- **`[verificado: comando]`**: ejecución real en esta sesión, con resultado detallado a continuación.
- **`[verificado: fuente externa]`**: documentación pública contrastada; no sustituye la compilación con Zig 0.17.1.
- **`[supuesto]`**: diseño o estado que no se comprobó directamente. Toda tarea futura o criterio de aceptación es propuesta, no resultado.

## Ejecuciones solicitadas y limitaciones reales

| Comando, en copia Z0 | Resultado observado | Estado |
|---|---|---|
| `just check` | `bash: just: command not found`; salida `127` | **No ejecutado efectivamente**: falta `just` `[verificado: comando]` |
| `just ecosystem-check` | `bash: just: command not found`; salida `127` | **No ejecutado efectivamente** `[verificado: comando]` |
| `just initializr-build` | `bash: just: command not found`; salida `127` | **No ejecutado efectivamente** `[verificado: comando]` |
| `python3 -m unittest discover -s tests -v` | `Ran 49 tests in 3.987s` / `OK (skipped=1)`; salida `0` | **48 pasan, 1 omitida** `[verificado: comando]` |
| `node --test packages/initializr-core/tests/planner.test.mjs` | `7` pasan; salida `0`; Node `v22.16.0` | Se ejecutó sobre el `dist/index.js` preexistente de otra copia Z0, cuyo `src/index.ts` coincide byte por byte (SHA-256 `c2a4d283…ef91ddd986`) con el del ZIP `[verificado: comando/archivo]` |
| `python3 scripts/check_layout.py` | `Setup required: zig fetch --save=zdata git+https://github.com/jhovadev/zigdataengine.git`; salida `1` | El ZIP **no** contiene la dependencia `zdata` ya fijada `[verificado: comando; build.zig.zon]` |

En este entorno no se dispone de `just`, `zig` ni `bun`; `node` disponible es v22, mientras `apps/initializr/package.json` requiere Node >=24. No se ejecutó `zig build`, `bun run typecheck`, `vite build`, builds cross-platform ni el Initializr en navegador. **No se afirma que fallen o pasen.** `[verificado: comando command -v / archivos package.json y mise.toml]`

La prueba omitida es `test_generated_file_paths_match_pure_ts_plan`, que requiere `packages/initializr-core/dist/index.js` dentro **de la misma copia**; el ZIP no trae ese archivo porque es un producto de build ignorado. La ejecución por separado de las 7 pruebas Node no sustituye esa prueba de paridad completa en el mismo workspace. `[verificado: tests/test_registry_z0.py; .gitignore; comando]`

Los logs proporcionados previamente por el desarrollador muestran `just initializr-build` y aplicaciones DVUI funcionando **en su máquina**; constituyen evidencia externa al ZIP y no sustituyen estas ejecuciones. `[verificado: registro de terminal aportado por el usuario; supuesto respecto al estado Git exacto de hoy]`

## Inventario por directorio (base Z0)

| Ruta | Función real encontrada | Evidencia |
|---|---|---|
| `build.zig`, `build.zig.zon` | Build raíz coordina `zevui.addApp` para CSV y minimal, y adjunta pruebas CSV; DVUI fijado; `zdata` ausente en el ZIP | `[verificado: build.zig; build.zig.zon]` |
| `justfile`, `mise.toml` | Orquestación de tests, targets, UI, Python y planner; fija Zig 0.17.1 con mise | `[verificado: justfile; mise.toml]` |
| `zevui/` (2 archivos) | `build.zig`: `addApp`, DVUI/SDL3, opciones y subsistema Windows; `config.zig`: tipos y overrides parciales | `[verificado: zevui/build.zig; zevui/config.zig]` |
| `zevui.zon`, `zevui.{windows,macos}.zon` | Identidad/ventana/apariencia y `zdata`; overrides de plataforma son literalmente `.{}` | `[verificado: zevui.zon; zevui.windows.zon; zevui.macos.zon]` |
| `src/` (14 archivos de origen) | CSV Explorer (`csv`, `search`, `bench`, `main`), app identity, UI tokens, hooks, componentes e iconos | `[verificado: src/main.zig; src/csv.zig; src/ui/*; src/app/identity.zig]` |
| `examples/` (3 archivos) | `examples/minimal` realmente tiene app DVUI y ZON; `examples/csv/build.zig` define tests/bench de CSV, **pero no contiene el frontend CSV** | `[verificado: examples/minimal/*; examples/csv/build.zig]` |
| `addons/` (2 archivos) | `memory_store.zig` y `design_tokens.zig` son fuentes Zig copiables, sin `addon.json`, `build.zig` ni `build.zig.zon` individuales | `[verificado: addons/*; listado Z0]` |
| `registry/` (3 archivos) | `catalog.json` es fuente de verdad única, `schema.json` describe esquema v2, README de gobernanza; no hay manifests por addon | `[verificado: registry/catalog.json; registry/schema.json; registry/README.md]` |
| `packages/initializr-core/` (4 archivos) | Planner TypeScript puro, tests `node:test`, tsconfig y package.json; resuelve requires/conflicts y operaciones `copy`/`render` | `[verificado: packages/initializr-core/src/index.ts; tests/planner.test.mjs]` |
| `apps/initializr/` (15 archivos) | UI SolidStart v2, rutas API y bridge de Node hacia Python; configuración Vite/Nitro, SVG y estilos | `[verificado: apps/initializr/src/routes/*; src/lib/bridge.server.ts; package.json]` |
| `initializr/` (12 archivos) | Generador, bridge, CLI y servidor legado Python, más HTML/CSS/JS; produce ZIP con files sintetizados en strings | `[verificado: initializr/generator.py; bridge.py; cli.py; server.py]` |
| `tests/` (11 módulos `.py`) | Contratos de branding, layout, seguridad, Initializr, paridad, targets y PE de Windows | `[verificado: tests/test_*.py]` |
| `scripts/` (4 scripts) | Validación de estructura, SDK preflight, selección de targets, inspección del subsistema PE | `[verificado: scripts/*.py]` |
| `docs/` (11 archivos) | Guías para build core, UI, SDKs, CI, Initializr, hidratación, integración, Z0; faltan ADR de los límites nuevos | `[verificado: docs/*.md]` |
| `.github/workflows/` (4 archivos) | CI de Zig, cross-smoke, desktop-compile e Initializr con compilación de starters en runners | `[verificado: .github/workflows/*.yml]` |
| `README.md`, `CONTRIBUTING.md` | Información del template, arquitectura de build y contribución al catálogo | `[verificado: archivos respectivos]` |
| `assets/`, `testdata/` | Branding/iconos de Windows y fixture CSV sintético | `[verificado: assets/*; testdata/sample_1500.csv]` |
| `.gitignore` | Ignora `.zig-cache/`, `zig-pkg/`, `zig-out/`, `dist/`, cachés Python, salida JS y `node_modules` | `[verificado: .gitignore]` |

**Nota sobre artefactos y Git:** el ZIP no incluye `.git` ni carpetas `dist/`, `zig-out/` o `zig-pkg/`. Por ello no se puede afirmar desde esta auditoría si algún artefacto estuvo previamente trackeado en el repo local; hay que comprobar `git ls-files` allí. El patrón genérico `dist/` también afectaría a un futuro `registry/dist/metadata.json`: el plan debe ajustar sus excepciones de `.gitignore` o publicar metadata de otro modo. `[verificado: ZIP Z0; .gitignore; supuesto: estado del índice Git local]`

## Grafo actual de dependencias

```text
build.zig (root)
 ├─ zevui/build.zig ──> dvui_sdl3 ──> SDL3
 │      └─ zdata [solo si config.modules.zdata]
 ├─ src/main.zig ──> src/{csv,search,ui,app} ──> zdata
 ├─ examples/csv/build.zig ──> tests/bench CSV ──> zdata
 └─ examples/minimal/main.zig ──> dvui + zevui_config

registry/catalog.json
 ├─ packages/initializr-core/src/index.ts ──> PLAN (vista previa)
 ├─ apps/initializr/src/lib/bridge.server.ts ──> lectura catálogo
 └─ initializr/generator.py ──> ZIP

apps/initializr/src/routes/index.tsx ──> TS planner
apps/initializr/src/routes/api/plan.ts ──> TS planner
apps/initializr/src/routes/api/generate.ts
 └─ bridge.server.ts (node:child_process)
     └─ python3 -m initializr.bridge ──> initializr/generator.py
```

`[verificado: build.zig; zevui/build.zig; src/main.zig; examples/csv/build.zig; packages/initializr-core/src/index.ts; apps/initializr/src/routes/{index,api/plan,api/generate}.tsx/.ts; apps/initializr/src/lib/bridge.server.ts; initializr/*.py]`

## Hallazgos solicitados (confirmados/refutados)

| # | Resultado | Evidencia y consecuencia |
|---|---|---|
| 1 | **Confirmado** | Vista previa `planProject` en TS; `POST /api/generate` llama a `spawn(python, ["-m", "initializr.bridge"])`. Dos caminos de generación. `[verificado: apps/initializr/src/routes/index.tsx; api/generate.ts; src/lib/bridge.server.ts]` |
| 2 | **Confirmado** | El CSV está en `src/`; `examples/csv/` solo declara pasos del build. `[verificado: árbol; build.zig]` |
| 3 | **Confirmado** | Addons son archivos Zig sueltos, no paquetes publicables. `[verificado: addons/*]` |
| 4 | **Parcialmente confirmado** | Catálogo monolítico y sin manifests, sí; pero **ya existe** esquema JSON y `schemaVersion: 2`; no debe decirse que carece de versión de esquema. La compatibilidad actual es exacta por arrays Zig/targets, no rangos semver. `[verificado: registry/schema.json; catalog.json]` |
| 5 | **Confirmado** | Ambos overrides son `.{}`; `Override` solo permite `identity.title`, `display_name` y dimensiones parciales. `[verificado: zevui.{windows,macos}.zon; zevui/config.zig]` |
| 6 | **Confirmado** | `unittest` Python y `node:test` TypeScript conviven. **No** se recomienda imponer un mismo runner: se unificarán *contratos y gates CI*, conservando runtimes adecuados por lenguaje durante la transición. `[verificado: tests/*; packages/initializr-core/tests/*; justfile]` |
| 7 | **Ignorados, no verificada su presencia trackeada** | `.gitignore` cubre `dist/`, `zig-out/`, `zig-pkg/`; el ZIP no trae esos artefactos. `[verificado: .gitignore; ZIP]` |
| 8 | **Confirmado** | ZData se declara `manual` y sin pin en el registro; `build.zig.zon` del ZIP no incluye `.zdata`; no hay `tools/pin-addon`. `[verificado: registry/catalog.json; build.zig.zon; árbol]` |

## Deuda técnica priorizada

1. **P0 — Dos fuentes de generación:** los archivos `build.zig`, `zevui.zon`, README y `src/main.zig` se producen con strings en Python, mientras TS produce únicamente operaciones; la paridad de **rutas** no equivale a paridad de **bytes**. `[verificado: initializr/generator.py; packages/initializr-core/src/index.ts; tests/test_registry_z0.py]`
2. **P0 — Build Core no publicable aisladamente todavía:** `zevui/build.zig` consume dependencia `dvui` desde el manifiesto del *consumidor*; faltan manifiesto propio, empaquetado de rutas y smoke tests como dependencia externa. `[verificado: zevui/build.zig; build.zig.zon]`
3. **P0 — Dependencias sin pin completo:** solo DVUI tiene `url+hash` en `registry/catalog.json`; ZData y futuros addons carecen de paquetes fijados. `[verificado: registry/catalog.json]`
4. **P1 — Addons copiados:** no exponen módulo Zig público ni test/build independiente, lo que impide una matriz de compatibilidad real. `[verificado: addons/*; initializr/generator.py]`
5. **P1 — Contrato de overrides limitado:** extenderlo sin romper `zevui.zon` necesita ADR y migración. `[verificado: zevui/config.zig]`
6. **P1 — Backend web Node-dependiente:** `node:child_process` y lectura de archivos desde un cwd de repo limitan la portabilidad del despliegue. `[verificado: apps/initializr/src/lib/bridge.server.ts]`
7. **P1 — CI sin constraints de importación:** jobs compilan pero no existe una regla automatizada formal que prohíba `framework -> examples/initializr/addons`. `[verificado: .github/workflows/*]`
8. **P2 — Configuración de tooling:** ZIP sin `bun.lock`; instalación en CI usa `bun install` sin `--frozen-lockfile`; actual Node de auditoría es <24. `[verificado: ZIP; .github/workflows/initializr-ui.yml; apps/initializr/package.json; comando]`

## Guardrails actuales que no deben perderse

- `addApp` usa `dvui_sdl3`; el subsistema Windows se establece a `.windows` salvo `windows_console=true`, y se adjuntan recursos Win32. `[verificado: zevui/build.zig]`
- `zevui_config` usa `addOptions`; `@embedFile` en `src/` evita los errores de rutas observados anteriormente. `[verificado: zevui/build.zig; src/app/identity.zig; src/ui/icons.zig]`
- `fingerprint = (crc32_ieee(name) << 32) | id32`, con `0 < id32 < 0xffffffff`; generación reproducible solo si se fija el ID. `[verificado: packages/initializr-core/src/index.ts; initializr/generator.py; tests/planner.test.mjs; tests/test_registry_z0.py]`
- El ZIP Python actual fija fecha `2026-01-01`, permisos `0644` y orden de archivos; valida un subconjunto fijo de rutas. La implementación TS futura tendrá que hacer pruebas de ZIP-slip, normalización y comparación real de bytes. `[verificado: initializr/generator.py; tests/test_initializr.py]`
- Los proyectos generados actualmente copian dos archivos `zevui/` y no requieren Node ni Python en ejecución; la promesa de dependencias únicamente publicadas con hash es **futura**. `[verificado: initializr/generator.py]`

## Qué falta verificar en el checkout real antes de F1

```sh
zig version
just --version
bun --version
node --version
just check
just ecosystem-check
just initializr-build
just initializr # comprobación de SSR/hidratación y generación
# Inspección de tracking e ignore:
git status --short
git ls-files dist zig-out zig-pkg
git check-ignore -v dist/ zig-out/ zig-pkg/ || true
# Comparación adicional tras compilar el planner:
just registry-check
python3 -m unittest tests.test_registry_z0 -v
```

Todos estos comandos son **criterios de verificación pendiente**, no resultados de esta auditoría. `[supuesto: ejecución futura en el checkout local]`
