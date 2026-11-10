# Zevui — propuesta de monorepo, contratos y decisiones

**Estado: PROPUESTA; no implementado.** Este documento no autoriza mover código. Se aplica a la base auditada en [`current-state.md`](current-state.md). Toda ruta del árbol es un **objetivo** `[supuesto]`, no evidencia de que exista hoy.

## Diseño recomendado

```text
zevui/
├── build.zig                       # shim de compatibilidad del workspace: zig build
├── build.zig.zon                   # root workspace; NO publicación del SDK
├── justfile                        # unifica gates para desarrolladores
├── framework/                      # paquete Zig publicable "zevui"
│   ├── build.zig
│   ├── build.zig.zon
│   ├── build/                       # addApp, config, assets, targets, windows, c_module
│   ├── src/                         # runtime: app, lifecycle, ui, tokens, store interfaces
│   └── tests/
├── addons/
│   ├── memory-store/
│   │   ├── addon.json               # metadata de publicación
│   │   ├── build.zig
│   │   ├── build.zig.zon
│   │   ├── src/root.zig
│   │   └── tests/
│   ├── design-tokens/              # migrar solo si no duplica framework/src/ui
│   ├── storage-json/
│   └── storage-sqlite/             # F6: piloto C, inicialmente experimental
│       ├── addon.json
│       ├── build.zig
│       ├── build.zig.zon
│       ├── src/
│       ├── vendor/                  # o dependencia C fijada, no ambos por defecto
│       ├── migrations/
│       └── tests/
├── registry/
│   ├── schema/addon.schema.json
│   ├── schema/metadata.schema.json
│   ├── catalog/                    # SOLO entradas versionadas/revisadas, no código C
│   └── dist/metadata-0.17.json     # salida publicada por canal; artefacto CI
├── templates/
│   ├── minimal/
│   │   ├── build.zig
│   │   ├── build.zig.zon
│   │   ├── zevui.zon
│   │   ├── src/main.zig
│   │   └── README.md
│   └── csv-explorer/               # opcional más adelante
├── initializr/
│   ├── apps/web/                   # SolidStart 2: UI/rutas muy delgadas
│   └── packages/core/
│       ├── src/registry/           # validación y resolución, sin lectura de disco
│       ├── src/plan/               # resolución -> plan determinista
│       ├── src/executors/zip.ts    # TS portable; ZIP con bytes normalizados
│       └── tests/
├── tools/
│   ├── pin-addon/                  # ejecuta zig fetch/guarda comprobación CI
│   ├── build-registry/
│   └── check-registry/
├── examples/
│   ├── minimal/
│   └── csv-explorer/               # MOVER desde src/ y examples/csv/
├── docs/
│   ├── architecture/
│   ├── adr/
│   ├── addon-authoring.md
│   └── migration.md
└── .github/workflows/
```

### Por qué estos límites

- **`framework/`** publica el SDK y el build helper; DVUI + SDL3 siguen siendo sus dependencias UI, no las de ZData. La API Zig pública incluye configuración tipada, `addApp`, lifecycle, wrappers de componentes/tokens y contratos de storage. Un runner configurable integra `dvui.App`, sin imponer una app concreta. `[supuesto: ADR-0001; verificado: zevui/build.zig conserva ya la integración SDL3]`
- **`addons/<id>/`** es un paquete Zig con `build.zig.zon` propio y `addon.json`, tests y módulo público. `design-tokens` puede ser parte base del framework **o** addon: habrá que escoger **una única fuente de tokens** para evitar duplicidad. Preferencia: primitivas y temas base en framework; packs de tema avanzados como addon. `[supuesto]`
- **`registry/`** es datos publicados; el CI inspecciona fuentes/manifiestos, resuelve hashes inmutables y publica `metadata-<zig-channel>.json`. Nunca ejecuta código de addon al servir metadata. Si el metadata se versiona en Git, ajustar `.gitignore` para no ignorar `registry/dist/` por accidente. `[supuesto; verificado: .gitignore actual contiene dist/]`
- **`templates/`** conserva los bytes de partida reales; el generador no debería contener Zig de varios cientos de líneas incrustado en strings TS/Python. `[supuesto; verificado: initializr/generator.py actual genera strings]`
- **`initializr/packages/core/`** debe exponer `validateMetadata`, `resolve`, `plan`, `render`, `zip` con separación entre lógica pura y ejecutores. No importa SolidStart, DOM ni módulos Node. Para mantener `core` totalmente puro, ubicar E/S (`fetch`, FileSystem, HTTP) en adapters fuera de `core`; ZIP puede ser un ejecutor determinista síncrono sobre los bytes ya suministrados. `[supuesto]`
- **`examples/`** consume el framework y addons como lo haría un cliente externo: **sin imports `../framework/src/*`**. En monorepo, desarrollo usa dependencias por path; release usa `url+hash` fijados. `[supuesto]`
- **Root** conserva un `build.zig` adaptador durante la transición para que `zig build`, `just check`, `just run` y `just minimal` sigan funcionando. Renombrar la carpeta local es opcional al final, no un paso técnico necesario. `[supuesto]`

## Reglas verificables en CI

| Regla | Comprobación propuesta | Prueba negativa |
|---|---|---|
| `framework` nunca importa `addons`, `registry`, `initializr`, `examples` ni `ZData` obligatoriamente | Script `tools/check-boundaries` analiza imports/ZON y `zig build` del paquete `framework/` aislado, con solamente sus dependencias declaradas | Introducir `@import("../../examples/...")` debe fallar |
| `addons` solo accede a la API pública de `framework` y a dependencias propias fijadas | Build de cada addon fuera del workspace + comprobación de imports | Import de `framework/src/internal/*` debe fallar |
| `examples` solo usa `framework` y addons como paquetes | Generación/build con `--cache-dir` limpio y dependencias por path registradas | Eliminar acceso al árbol root y seguir compilando |
| `registry` es datos y manifiestos, no importa/runtime de Zig | `check-registry`: JSON schema, SPDX, URI/hash, semver y rutas; regeneración bit a bit | Hash sin verificar o addon `available` sin build debe fallar |
| `initializr` solo consume `registry/dist` y templates; `framework` nunca depende de él | ESLint/TS boundary checks + grep/import graph, tests de contrato | Importar `@solidjs/start` en `initializr/packages/core` debe fallar |
| `addApp` conserva Windows GUI y el debug override | Build Windows y análisis de PE `subsystem=2` para GUI vs consola en debug | Un build Windows GUI marcado console debe fallar |
| Addons desactivados no se enlazan | Smoke con un módulo C/SQLite `.off`, inspección de objetos/imports | SQLite debe quedar fuera del binario `.off` |

`[supuesto: gates de CI futuros; verificado: scripts/verify_windows_gui.py ya existe y comprueba PE en la base]`

## Contratos públicos antes de programar

1. **Build:** `zevui.addApp(b, cfg, opts)` es API declarativa, con paquete importable desde otro `build.zig`; CI debe verificar el **nombre de import exacto** con Zig 0.17.1 antes de publicarlo. No afirmar que un simple `@import("zevui")` funciona externamente sin esa prueba. `[supuesto; verificado: zevui/build.zig funciona como archivo local]`
2. **Runtime:** módulos públicos para `App`, `ui`, `design`, `storage`; los tipos y ownership de handles, callbacks e I/O deben quedar documentados antes de congelar semver. DVUI maneja la UI, no una WebView. `[supuesto]`
3. **`zevui.zon`:** **mismas claves actuales** (`identity`, `window`, `appearance`, `modules`) mientras se migra. Añadir campos solo con defaults y ADR; un `zevui.zon` M0.5 debe seguir siendo válido. Overrides: solo campos opcionales autorizados, `null` significa heredar, valores escalares sobrescriben, listas reemplazan enteras, nunca fusionar dependencias de `build.zig.zon` automáticamente. `[supuesto; verificado: zevui/config.zig actual]`
4. **Manifest addon (`addon.json`):** `schemaVersion`, `id`, `version`, `kind` (`zig|c-bundled|c-system`), `status` (`available|planned|deprecated`), `provides`, `requires`, `conflicts`, `compat.zig`, `compat.zevui`, `compat.targets`, `package{url,hash}`, `options`, `files`, `license` (SPDX), `trust`; `package` obligatorio al publicar `available` y puede ser omitido durante desarrollo/planificación. Conservar una transición `manual -> planned` para ZData sin pretender que sea funcional. `[supuesto: ADR-0003]`
5. **Plan:** tipo versionado con `fingerprintId` fijo, dependencias resueltas, archivos, sha256 esperados y operaciones ordenadas; el resultado del plan no ejecuta scripts. La UI, ZIP/API y futura CLI parten del mismo plan. `[supuesto: ADR-0002]`

## Decisiones A–G: recomendación, intercambio y reversa

| Decisión | Recomendación y trade-off | Reversa |
|---|---|---|
| A. Monorepo vs multirepo | **Monorepo** hasta estabilizar contratos; una CI prueba todos los consumidores. Coste: builds/PR más grandes. **No renombrar** la carpeta local aún. `[supuesto]` | Extraer `framework/` a repo propio con historial `git filter-repo` o `git subtree` si se necesitan ciclos de lanzamiento independientes. |
| B. JSON vs ZON | **JSON** para manifests/metadata por compatibilidad web y JSON Schema, **ZON** para apps Zig. Coste: dos formatos, un esquema único. `[supuesto]` | Generar JSON desde ZON en CI y mantener API JSON estable. |
| C. Python | Eliminar del **runtime web** en F2; mantener `generator.py` temporalmente solo como oráculo de golden/paridad (aislado, sin rutas de producción). Coste de transición dual. `[supuesto]` | Rehabilitar API Python detrás de flag mientras se corrigen discrepancias, sin borrar golden tests. |
| D. Canales Zig | Publicar `0.17` (con pin de patch exacto 0.17.1) y metadata por canal; no mezclar ABI de 0.16/0.17. Coste: matriz CI. `[supuesto]` | Servir un único canal 0.17 estable sin romper `metadata` versionada. |
| E. Módulos C | `c-bundled` por defecto para SQLite, `system` explícito, `off` stub sin link. **En Zig 0.17.x usar el paquete `translate-c` fijado y su `Translator`, no basarse en `@cImport` ni empezar con un helper deprecado**. `[verificado: fuente externa https://github.com/ziglang/translate-c; https://ziglang.org/download/0.17.0/release-notes.html; supuesto: API integradora]` | Mantener SQLite experimental, retirar registro `available`; volver a wrapper pre-generado verificado para 0.17.1. |
| F. ZIP determinista | Orden lexicográfico bytewise, path POSIX seguro, timestamps constantes (ZIP DOS >=1980), permisos `0644/0755`, UTF-8, LF para archivos textuales y bytes originales para binarios; rechazar `..`, paths absolutos, symlinks inesperados, duplicados/case-collisions. Coste: disciplina de assets. `[supuesto]` | Mantener el ZIP Python como oráculo y flag de fallback mientras el nuevo ejecutor falla comparación. |
| G. Testing | Un solo **comando/gate de aceptación**, no un solo framework de tests: unit TS, Zig y smoke de packages, golden ZIP, test por pares, cross-compile sin ejecutar, runner nativo por OS, canario Zig master no bloqueante. Coste CI. `[supuesto]` | Reducir temporalmente la matriz de targets por estados documentados sin declarar plataformas verificadas. |

**Nota sobre Zig 0.17:** el paquete oficial `translate-c` se anuncia como reemplazo de `@cImport`; `std.Build.Step.TranslateC` existe pero ha sido marcado para deprecación. `getEmittedIncludeTree()` no debe tratarse como sustituto universal de traducción de encabezados: es una API de publicación/inclusión de headers de pasos de compilación. Verificar el contrato exacto `Translator.mod` + linking C con Zig 0.17.1 en F6. `[verificado: fuentes externas https://ziglang.org/download/0.17.0/release-notes.html, https://github.com/ziglang/translate-c; supuesto: implementación F6]`

## Backlog UI (fuera de F1–F6 de infraestructura)

| Prioridad | Funcionalidad | Contrato con el core |
|---|---|---|
| U1 | Selector Zig/Zevui y targets Windows/macOS/Linux | Consume canales, compatibilidad y `resolve`; no reimplementa reglas |
| U1 | `storage` como selección única | `provides`/grupo de exclusión en manifest, no lógica hardcodeada |
| U1 | Detalles addon: licencia, tamaño, kind, requires/conflicts, estado | Viene de metadata firmado/revisado |
| U1 | Avisos de dependencias automáticas y conflictos | Muestra el árbol/resolución del plan |
| U2 | Árbol de archivos con resaltado y diff antes de descargar | Lee operaciones reales y hashes del plan |
| U2 | `curl` equivalente y enlace compartible | API `/metadata` + `/starter.zip`, fingerprint incluido |
| U2 | Teclado, foco, contraste, aria-live, lectores de pantalla | Pruebas accesibilidad; ninguna regresión de hidratación SSR |
| U3 | Páginas estáticas por addon (SSG/SEO) | Se generan desde metadata; no construyen paquetes |

Todo el backlog UI es **propuesto** y debe tener PRs separados del refactor de carpetas. `[supuesto]`

## Preguntas que requieren aprobación (máximo cinco)

1. ¿Aceptamos **monorepo sin cambiar por ahora** `~/Documents/sideProjects/zdata-dvui-examples`, con `zevui` como nombre del paquete público? (Recomendado: sí.)
2. ¿Publicamos el registro inicial **cerrado/oficial** con revisión y `metadata-0.17.json` versionado? (Recomendado: sí.)
3. ¿Confirmamos que **JSON será el store opcional predeterminado** para ajustes y SQLite será addon bajo demanda, conservando `zevui.zon` para build? (Recomendado: sí.)

La aprobación autoriza comenzar **F1**, no ejecutar F1–F6 de una vez. `[supuesto]`
