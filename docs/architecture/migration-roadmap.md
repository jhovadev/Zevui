# Zevui — roadmap de migración F1–F6 (propuesto)

**NO EJECUTADO.** Una fase equivale a **un PR/commit revisable**; al cerrar cada fase `just check` y los gates existentes deben seguir verdes en el checkout del usuario. `git mv` solo cuando el fichero esté trackeado; confirmar con `git ls-files` antes de mover. Siempre registrar el SHA base y conservar una rama de recuperación. `[supuesto: plan; verificado: las rutas antiguas existen en ZIP Z0 según current-state.md]`

## Gates comunes de todas las fases

```sh
just check                         # incluye Zig ReleaseSafe, requiere pin zdata
just ecosystem-check              # TS planner + contratos Python durante migración
just initializr-build             # SolidStart typecheck + Vite/Nitro
zig build -Doptimize=ReleaseSafe
zig build minimal -Doptimize=ReleaseSafe
# En CI: build de starters generados y comprobación Windows PE subsystem GUI
```

A partir de F2, `just ecosystem-check` dejará de ejecutar Python en producción: mantendrá suites de oráculo aparte hasta retirarlas por decisión documentada. Si `just check` requiere hardware gráfico no disponible en CI, conservar el paso headless y añadir runners GUI para smoke: **no bajar ni borrar gates** sin reemplazo explícito. `[supuesto; verificado: comandos existentes en justfile]`

## F1 — Documentación, ADR y contract tests: **sin mover código**

| Ruta antigua | Ruta nueva / cambio previsto |
|---|---|
| `docs/ecosystem-z0.md` | Se conserva; enlaces a `docs/architecture/*` y `docs/adr/*` |
| `README.md`, `CONTRIBUTING.md` | Solo actualizar mapa y reglas, sin cambiar la API |
| `scripts/check_layout.py` | Añadir tests de límites sin activar rutas todavía (modo diagnóstico para target futuro) |

**Aceptación:** ADR-0001 a ADR-0005 revisados; inventario real contra Git actualizado, `just check`, `just ecosystem-check`, `just initializr-build` verdes; archivo de `git status` limpio después del commit. **Riesgos:** documentación adelantada al código. **Reversa:** `git revert <commit-F1>`; ningún consumidor cambia. `[supuesto]`

## F2 — Una fuente de generación: planner TS y executor ZIP

| Ruta antigua | Ruta nueva / cambio previsto |
|---|---|
| `packages/initializr-core/**` | `initializr/packages/core/**` (`git mv`) |
| `apps/initializr/**` | `initializr/apps/web/**` (`git mv`, actualizar import aliases/Vite) |
| `initializr/generator.py` | Se congela temporalmente como oráculo en `tests/golden/legacy_generator.py` sin servir tráfico; **no** borrarlo hasta equivalencia |
| `initializr/bridge.py`, `apps/initializr/src/lib/bridge.server.ts` | API/adapter TS que consume el mismo `Plan`; eliminar `node:child_process` de producción |
| `apps/initializr/src/routes/api/generate.ts` | `initializr/apps/web/src/routes/api/generate.ts`: wrapper fino de `executeZip(plan, assets)` |
| `registry/catalog.json` | Sigue siendo fuente de metadata durante esta fase, para reducir riesgo |

**Aceptación:** mismo input + mismo `fingerprintId` → *bytes ZIP idénticos* en dos ejecuciones TS, `plan.operations` coincide con todos los archivos y contenido, golden fixture vs Python legacy; ZIP-slip, zip bomb límites, DOS time/permisos/LF, sin Node en `core`, navegación SSR y descarga local. API estable de `POST /api/generate` hasta introducir `/starter.zip`. CI compila starter mínimo y starter con ambos addons Zig en host. **Riesgos:** divergencia Python/TS, bundling JS y SSR con rutas movidas. **Reversa:** flag `ZEVUI_GENERATOR=legacy` por una sola release de transición, `git revert <commit-F2>` si no se cumple; mantener snapshots golden. `[supuesto]`

## F3 — `framework/` publicable + CSV en examples

| Ruta antigua | Ruta nueva / cambio previsto |
|---|---|
| `zevui/config.zig` | `framework/build/config.zig` (`git mv`) |
| `zevui/build.zig` | `framework/build/root.zig` o `framework/build.zig` (public API; `git mv`) |
| `src/ui/{tokens,components,hooks,dvui_style,icons}.zig` | `framework/src/ui/**` **solo lo genérico**; mantener especializaciones CSV en su ejemplo |
| `src/{main,csv,search,bench}.zig` | `examples/csv-explorer/src/**` (`git mv`) |
| `src/app/{identity,assets}/**` | Branding propio a `examples/csv-explorer/src/app/**`; opciones de aplicación genéricas a framework |
| `examples/csv/build.zig` | `examples/csv-explorer/build.zig` (`git mv`) |
| `zevui.zon`, `zevui.windows.zon`, `zevui.macos.zon` | `examples/csv-explorer/` como consumidores; `build.zig` root shim sigue reconociendo scripts actuales |
| `examples/minimal/**` | Conservar como consumidor y migrar a imports públicos del framework |

**Aceptación:** `framework/` tiene `build.zig.zon`, `build.zig`, paths cerrados; `zig fetch` desde un **repositorio o archivo local de prueba** instala el SDK externamente, `@import` de API pública probado en 0.17.1 con app completamente externa; minimal no importa CSV/ZData; CSV renderiza, búsqueda/tabla funcionales; Windows sigue GUI sin consola y debug con consola. No ampliar `zevui.zon` sin ADR/compat. **Riesgos:** roots de `@embedFile`, ABI del build, DVUI SDL3, assets y rutas de `just`. **Reversa:** `git revert <commit-F3>`; conservar shim root y alias antiguos un release. `[supuesto]`

## F4 — Addons como paquetes y registro por addon

| Ruta antigua | Ruta nueva / cambio previsto |
|---|---|
| `addons/memory_store.zig` | `addons/memory-store/src/root.zig` (`git mv`), agregar `addon.json`, `build.zig`, `.zon`, tests |
| `addons/design_tokens.zig` | `addons/design-tokens/src/root.zig` **si** es plugin adicional, o `framework/src/ui/tokens.zig` si se decide que es core |
| `registry/schema.json` | `registry/schema/addon.schema.json` + `metadata.schema.json` (compat via redirect/alias en transición) |
| `registry/catalog.json` | `registry/catalog/*/addon.json`, con `registry/dist/metadata-0.17.json` generado |
| No existe `tools/pin-addon` | Crear `tools/pin-addon`, `tools/build-registry`, `tools/check-registry` |
| `initializr/...` | Leer solo metadata generada y dependencias url+hash; no copiar código de addon al starter |

**Aceptación:** `zig fetch` fija paquetes verificables por versión desde CI (nunca hashes inventados), 2 paquetes addons compilan de forma independiente; `validateMetadata` rechaza licencias inválidas, rutas traversal, hash ausente, conflicto/ciclo/compat; generated `build.zig.zon` lleva `zevui` + addon(s) fijados, el programa consume módulos desde gestor Zig, **sin código `addons/*.zig` copiado**. Pruebas por pares entre disponibles. Ajustar ignore de `registry/dist`. **Riesgos:** URLs inmutables, schema migration, publicación y nombre del módulo; **Reversa:** volver a metadata v2 congelada temporalmente y revertir PR, nunca eliminar pins antiguos usados por releases. `[supuesto]`

## F5 — Plantilla de archivos reales y CI de starters por target

| Ruta antigua | Ruta nueva / cambio previsto |
|---|---|
| Strings `build.zig`, `zevui.zon`, README en `initializr/generator.py` (ya congelado) | `templates/minimal/{build.zig,build.zig.zon,zevui.zon,README.md,src/main.zig}` |
| `examples/minimal/main.zig` como plantilla implícita | `templates/minimal/src/main.zig` independiente; ejemplo consume template generado o prueba paridad |
| Tests de salida Python | `initializr/packages/core/tests/golden/*`, pruebas de render, byte identity y seguridad |
| Workflow de starters bajo Initializr | Matriz explícita por Zig/OS/target; CI de headless/native limitada según SDK |

**Aceptación:** golden bytes deterministas en cliente browser, Worker y Node (misma entrada/assets); generador solo renderiza archivos de `templates/`; build real `zig build test && zig build` para mínimos y combinaciones; cross-compile Linux/Windows/macOS donde se disponga del SDK adecuado, sin interpretar la compilación cruzada como ejecución; matriz de compatibilidad publicada y canario de Zig master no bloqueante. **Riesgos:** `@embedFile` en templates, empaquetado de assets binarios, CORS/CDN, frameworks macOS. **Reversa:** mantener commit anterior del catálogo/generador y revertir el PR sin cambios a apps creadas. `[supuesto]`

## F6 — Piloto C: storage SQLite real

| Ruta antigua | Ruta nueva / cambio previsto |
|---|---|
| Registro `sqlite` en estado `planned` | `addons/storage-sqlite/` como paquete versionado, experimental hasta aprobar gates |
| Sin módulo C público | `addons/storage-sqlite/{build.zig,build.zig.zon,src/,vendor/,migrations/,tests/}` |
| `registry/catalog/...` | Manifest `storage-sqlite/addon.json` con `kind: c-bundled`, licencia y pin verificados |
| Configuración ausente | Opción `-Dsqlite=bundled|system|off` con `off` stub que no enlaza C |

**Aceptación:** SQLite real preparado/ejecutado en Linux/Windows/macOS (runners nativos cuando sea necesario), transacciones y migraciones versionadas + checksum/rollback; cero librerías SQLite en el binario con `off`; con `system` doctor comprueba SDK y muestra errores útiles; C wrapper enlazado a `zevui_module`, bindings vía paquete `translate-c` fijado y probado en **Zig 0.17.1** (API exacta por decidir); tests de conformidad KeyValueStore para Memory/JSON/SQLite según capacidades. **Riesgos:** licencias de vendor, build cross-target y linker, ownership de punteros C, cambios de API de translator. **Reversa:** retirar `available` del registro, conservar pin con estado `deprecated` si ya se publicó; el core sigue compilando sin SQLite. `[supuesto]`

## Cierre de cada PR

- Registrar SHA base, comandos completos y sus códigos de salida, hashes Zig fetch, targets efectivamente construidos y casos sin ejecutar.
- Una comprobación de nombre/ruta en documentación no equivale a compilación real Zig/SDL3.
- No incorporar Python, SolidStart ni Node a un binario Zig generado.
- Detener la migración inmediatamente ante regresión de CSV Explorer, `addApp`, Windows PE GUI o lectura de `zevui.zon` antiguo.

`[supuesto: criterios futuros]`
