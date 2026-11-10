# ADR-0001 — Monorepo y límites de los cuatro productos

- **Estado:** Propuesto, pendiente de aprobación.
- **Fecha:** 2026-11-10.
- **Ámbito:** `framework/`, `addons/`, `registry/`, `initializr/` y consumidores `examples/`.

## Contexto

El SDK está actualmente en `zevui/` como dos archivos locales; la UI CSV reside en `src/`, el build raíz coordina dos ejecutables, y las dependencias por paquete no están separadas. `[verificado: build.zig; zevui/build.zig; src/main.zig; examples/minimal/main.zig]`

## Decisión propuesta

Conservar un **monorepo** con cuatro productos que se publiquen y prueben de forma autónoma: Zig SDK (`framework/`), paquetes Zig (`addons/`), metadatos (`registry/`) y generador web+core (`initializr/`). `examples/` solo consume API pública. Build raíz permanece como shim de compatibilidad; no renombrar directorio local ni repositorio durante la migración. `[supuesto]`

Contrato de importación: `framework` → DVUI/SDL3/stdlib (no import de ZData, addons, registry o web); `addons` → API pública del framework + dependencias fijadas; `registry` → datos; `initializr` → metadata+templates, jamás código compilado de framework; `examples` → framework + addons. CI comprobará import graph estático **y** aislamiento de compilación externa. `[supuesto]`

## Alternativas y consecuencias

- Multirepo desde el inicio: releases independientes, pero rompe atomicidad de cambios de API y aumenta coste de CI; diferir. `[supuesto]`
- Monorepo sin límites: cambios fáciles al inicio pero acoplamiento circular; rechazado. `[supuesto]`
- Consecuencia: releases de paquetes independientes requieren tags/artefactos inmutables y matriz de compatibilidad propia. `[supuesto]`

## Validación y reversa

F3: publicar/build aislado de `framework`, dos apps externas (minimal y CSV) importan API pública. F4: cada addon compila solo. Si falla, revertir PR y conservar shim raíz; si se necesitan repos separados en el futuro, extraer historial por prefijo sin cambiar APIs. `[supuesto]`
