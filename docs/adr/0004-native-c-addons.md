# ADR-0004 — Convención de addons C/SQLite para Zig 0.17.1

- **Estado:** Propuesto, pendiente de aprobación.
- **Fecha:** 2026-11-10.

## Contexto

No existe aún un módulo SQLite real en Z0 ni un ejemplo compilado `c-bundled`. La API del builder actual solo configura DVUI y opcionalmente ZData. `[verificado: addons/*; zevui/build.zig; registry/catalog.json]`

## Decisión propuesta

Cada addon C es paquete Zig autónomo que expone un módulo público **`zevui_module`**, con el wrapper idiomático como raíz; el build del addon se ocupa de linking, `libc`, include paths, fuentes C y traducción de tipos. El consumidor no importa headers ni conoce `sqlite3.h`. El paquete solo declara dependencias explícitas y pins Zig. `[supuesto]`

Para SQLite: `-Dsqlite=bundled|system|off`; predeterminado `bundled` con amalgama auditada y licencia revisada, `system` opt-in y diagnóstico de headers/lib en cada OS, `off` compila un stub del mismo contrato **sin enlazar C**. APIs de prepared statements, SQLite WAL, ownership claro, errores Zig, migraciones versionadas + checksum/rollback. Pruebas de conformidad alineadas con `KeyValueStore`; no forzar SQL sobre JSON/ZON. `[supuesto]`

### Corrección de compatibilidad importante

En Zig 0.17, el mecanismo recomendado para C headers es la **dependencia externa oficial `translate-c`** (`Translator.init(...).mod`), no `@cImport` (removido) ni depender indefinidamente de `std.Build.Step.TranslateC` (deprecado). El paso de publicación de headers (`getEmittedIncludeTree()`) tiene otro propósito y no constituye por sí solo la traducción. La combinación final de `translate-c`, módulo wrapper y enlazado C se probará con el SDK instalado de **Zig 0.17.1** antes de fijar la API. `[verificado: fuente externa https://ziglang.org/download/0.17.0/release-notes.html y https://github.com/ziglang/translate-c; supuesto: contrato de Zevui]`

## Trade-offs y seguridad

`c-bundled` reproduce mejor el build cross-target, pero añade peso y responsabilidad de actualizaciones de CVEs/licencia. `c-system` reduce vendor pero degrada portabilidad. Un hash fija contenido, **no** seguridad de scripts de build; CI necesita revisión de C, SBOM, escaneo y ejecutables compilados en runners aislados. `[supuesto]`

## Validación y reversa

F6: `zig build test` por host, cross-compile por target admitido, runner nativo macOS/Windows/Linux para smoke, tests de prepared statements/migraciones/locking, verificación de stub `off` sin símbolos SQLite. Si falla, conservar addon experimental/no disponible, revertir PR F6 sin cambiar `framework/`, mantener pins ya publicados pero marcar versión como deprecated. `[supuesto]`
