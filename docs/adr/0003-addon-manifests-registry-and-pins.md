# ADR-0003 — Manifiestos JSON, catálogo generado y pins inmutables

- **Estado:** Propuesto, pendiente de aprobación.
- **Fecha:** 2026-11-10.

## Contexto

`registry/catalog.json` está versionado con `schemaVersion: 2` y tiene un único pin DVUI; los addons disponibles son dos ficheros Zig sin manifiestos. ZData está `manual`, SQLite/tray/bundle `planned`. `[verificado: registry/catalog.json; registry/schema.json; addons/*]`

## Decisión propuesta

Un `addons/<id>/addon.json` por paquete, validado por `registry/schema/addon.schema.json`. Campos mínimos: `schemaVersion`, `id`, `name`, `version`, `kind: zig|c-bundled|c-system`, `status: available|planned|deprecated`, `license` SPDX, `trust`, `provides/requires/conflicts`, `compat.{zig,zevui,targets}`, `options`, `files` seguros, `package.{url,hash}` **requerido para cualquier versión marcada como `available` y publicada**. Distinguir addon del framework/base y addon de ejemplo. `[supuesto]`

`tools/pin-addon` debe ejecutar `zig fetch` en CI/release para obtener el **hash real de contenido** y registrar un URL inmutable (commit/tag firmado/archivo inmutable); jamás generar hashes simulados en navegador. `tools/build-registry` produce metadata JSON por canal, estable/determinista, sin ejecutar código de addons; `tools/check-registry` verifica esquema, referencias, licencias, hash, duplicados, compatibilidad y trazabilidad de artefactos. La CI de compilación sí ejecutará build Zig en sandbox/runners. `[supuesto; verificado: build.zig.zon y registry/catalog.json ya tienen un hash DVUI]`

**Importante:** `registry/dist/metadata-0.17.json` requiere una excepción explícita al `.gitignore` actual que excluye `dist/`, o publicación como artefacto de release; la elección debe quedar documentada. `[verificado: .gitignore; supuesto: nueva ruta]`

## Trade-offs

JSON permite JSON Schema y consumo directo del navegador; ZON sería más cercano a Zig pero requeriría exportador y nuevo parser en la web. Un catálogo oficial cerrado facilita verificación de C/transitivas; abrir community antes de CI/mandatos de revisión es demasiado riesgo. `[supuesto]`

## Migración, validación y reversa

F4 genera metadata v3 a partir de los manifests sin borrar metadata v2 hasta que consumidores migren; `manual` viejo mapea a `planned` con razón. Tests de integración: addon `available` sin `package.hash` falla; `zig fetch` comprueba hash; dos apps de ejemplo compilan solo con paquetes fijados; old links a Z0 mantienen compat por periodo documentado. Reversa: seguir sirviendo v2 en URL separada, sin mutar hashes publicados. `[supuesto]`
