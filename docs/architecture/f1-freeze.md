# F1 — Congelar los contratos antes de mover el monorepo

**Estado:** preparado para revisión; **no** implica aprobar automáticamente los ADR pendientes.
**Alcance:** documentación, contratos de regresión y CI existente; ningún archivo de producto se mueve en F1.

Este documento complementa [`current-state.md`](current-state.md),
[`target-architecture.md`](target-architecture.md) y
[`migration-roadmap.md`](migration-roadmap.md). Las rutas de origen son las de
**Zevui Z0**; no son todavía la arquitectura final.

## Contratos congelados para la migración

| Contrato | Base actual | Qué preservar | Evidencia |
| --- | --- | --- | --- |
| SDK / build | `zevui/build.zig` + `zevui/config.zig` | Las dos aplicaciones siguen entrando por `zevui.addApp`; la app mínima no requiere ZData | [verificado: `build.zig`, `examples/minimal/main.zig` en la copia Z0]; gate `just check` pendiente de ejecución local |
| Config pública | `zevui.zon`, `zevui.windows.zon`, `zevui.macos.zon` | No renombrar claves públicas sin ADR + migración de esquema | [verificado: archivos ZON en copia Z0] |
| Inicializador | `packages/initializr-core/` + `initializr/generator.py` | F2 sustituye **ambas** rutas de generación por un único ejecutor TS y prueba paridad antes de eliminar el bridge Python | [verificado: `initializr/bridge.py`, `apps/initializr/src/lib/bridge.server.ts` en copia Z0] |
| Addons | `addons/*.zig`, `registry/catalog.json` | No publicar un addon como `available` hasta compilarlo aisladamente y fijar URL+hash reales | [verificado: catálogo Z0; supuesto: contrato de publicación futura] |
| Windows | `build.zig` + `zevui/build.zig` | GUI sin consola por defecto, variante de depuración con consola; verificar PE subsistema 2 en binario real | [verificado: `tests/test_windows_gui_binary.py`; ejecución real pendiente] |
| Recursos | `src/app/assets`, `src/ui/assets` | No usar `@embedFile` con rutas fuera de la raíz del módulo | [verificado: test `test_embedded_assets.py`] |
| Generación | Registry + planner TS + Python ZIP | Conservación del fingerprint y de generación segura; F2 añade bytes deterministas con **un único** ejecutor | [verificado: suites de Z0; supuesto: gate F2] |

## Gates y evidencia por PR

Ejecutar desde la raíz del checkout. Anotar código de salida y versión de
Zig/Bun, no solamente un resumen de tests. Nunca indicar `PASS` si no se ejecutó.

```sh
zig version
just check
just ecosystem-check
just initializr-build
python3 -m unittest discover -s tests -v
git diff --check
```

Al introducir F2 o F3, ejecutar adicionalmente los builds de las dos apps y
sus targets compatibles. `just run` necesita sesión gráfica, y la compilación
cruzada no sustituye una prueba de ejecución nativa. Conserva el CSV Explorer y
el comportamiento Windows GUI en todos los PR; Zig Data Engine es un repositorio
externo que esta migración **no** modifica.

## Reglas de historial y reversión

1. Crear primero un commit base que incluya Z0 + los documentos F0.
2. F1 debe ser **otro commit** con solo documentos y tests de contrato; no hacer
   `git mv` antes de que los archivos estén versionados.
3. Mantener una rama de integración y una rama de respaldo o etiqueta sobre el
   commit base; proponer cada fase F2–F6 como PR/commit independiente.
4. Si falla cualquier gate, detener la fase. Si ya se registró el commit,
   preferir `git revert <sha>` y no reset destructivo en ramas compartidas.
5. Las rutas que cambien en F2–F6 deben actualizarse en los tests de contrato
   **en la misma fase**, sin silenciar pruebas ni aceptar que la documentación
   de estado actual pase por arquitectura futura.

## Criterio de cierre F1

- [ ] Commit base Z0+F0 registrado y SHA anotado.
- [ ] ADR-0001..0005 revisados por el mantenedor; su estado se cambia en un
      commit específico cuando se aprueben.
- [ ] `just check`, `just ecosystem-check`, `just initializr-build` ejecutados
      y resultados anotados en el PR/commit.
- [ ] `tests/test_architecture_f1.py` aprobado en Zig Z0 antes de mover rutas.
- [ ] `git status --short` limpio al terminar el commit F1.

**Reversa:** revertir el commit F1. No se cambia ningún módulo de producto.
