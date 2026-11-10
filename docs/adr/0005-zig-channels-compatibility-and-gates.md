# ADR-0005 — Canales Zig, compatibilidad y criterios de publicación

- **Estado:** Propuesto, pendiente de aprobación.
- **Fecha:** 2026-11-10.

## Contexto

Z0 declara solo `supportedZig: ["0.17.1"]`; cada addon lista versiones exactas de Zig y targets, sin rango semver ni matriz de verificación. La CI ejecuta tests Python/TS y algunos builds Zig; no hay gates formales de publicación de packages externos ni combinación por pares. `[verificado: registry/catalog.json; packages/initializr-core/src/index.ts; .github/workflows/*.yml]`

## Decisión propuesta

Canal de catálogo **`0.17`**, con toolchain efectivo exacto `0.17.1` inicialmente y pins por versión publicada. Cada release de Zevui define versión semver y tabla Zig minor compatible. `metadata-0.17.json` contiene marcas `available`, `experimental`/`planned` de UX de forma que **solo** `available` se puede generar; los manifests distinguen disponibilidad y confianza. URL de metadata estable por canal, con identificador de versión, ETag y hash. `[supuesto]`

Gate de release: JSON Schema + SPDX, URI/hash verificables con `zig fetch`, static import boundaries, `zig build` aislado de `framework/` y addons, `just check` verde, golden ZIP, compilation de starter sin JS/Python, matrices por OS/arch y combinaciones por pares. Canario Zig master **informativo**, no requisito de release. Declarar resultado de compilación cruzada como `cross-compiled`, nunca como `runtime-verified`. `[supuesto]`

`framework` adopta API versionada de `zevui.zon`: claves existentes se mantienen; campos nuevos con defaults, overrides por OS limitados a rutas tipadas; cualquier renombre requiere ADR y traductor explícito entre esquema viejo/nuevo. `[supuesto]`

## Trade-offs y reversa

Más canales implican pruebas más lentas, pero impiden vender compatibilidad no verificada. No prometer compatibilidad binaria entre Zig minor. Si el gate se vuelve demasiado caro, reducir targets en estado experimental (con señal visible), nunca eliminar tests básicos. El metadata previo y sus hashes deben permanecer descargables; revertir un release cambia el *puntero de canal*, no reescribe assets inmutables. `[supuesto]`

## Métricas de aprobación

- 2 aplicaciones externas que importan el mismo Zevui SDK, sin copiar build helpers.
- 2 addons Zig independientes y probados fuera del monorepo.
- ZIP idéntico con misma selección/fingerprint/versión metadata.
- `zig build` funciona en un proyecto generado offline **después de obtener y cachear sus dependencias Zig**; no prometer una instalación offline inicial sin los paquetes disponibles.
- Windows GUI sin consola de forma predeterminada y consola solo en override debug.
- Addon no disponible o hash sin verificar nunca aparece como seleccionable.

Todo lo anterior son **criterios futuros**, no pruebas ejecutadas. `[supuesto]`
