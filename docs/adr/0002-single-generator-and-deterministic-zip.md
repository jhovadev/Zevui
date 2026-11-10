# ADR-0002 — Un solo planificador/generador TypeScript y ZIP determinista

- **Estado:** Propuesto, pendiente de aprobación.
- **Fecha:** 2026-11-10.

## Contexto

Z0 calcula la vista previa con `planProject()` en TypeScript, pero la descarga invoca `python3 -m initializr.bridge` desde `node:child_process`, que a su vez ejecuta un generador con strings de Zig. Existe una prueba de paridad de **rutas**, no de bytes para todos los archivos. `[verificado: packages/initializr-core/src/index.ts; apps/initializr/src/lib/bridge.server.ts; initializr/generator.py; tests/test_registry_z0.py]`

## Decisión propuesta

F2 introduce `initializr/packages/core`: `validate → resolve → plan → render` como funciones TS puras (inputs inmutables, sin DOM, Node APIs, red ni disco). El ejecutor `zip` consume exclusivamente un plan y bytes de assets; `initializr/apps/web` expone API y UI delgada. El Python actual pasa a fixture/oráculo de compatibilidad hasta igualar el resultado; **no corre en producción**. `[supuesto]`

El fingerprint CRC-32 del nombre conserva la mitad alta y un id32 explícito (`1..0xfffffffe`); no introducir aleatoriedad *dentro* del planificador. El controlador de creación aporta el id una vez y lo incluye en la URL compartible o request. `[verificado: código actual de fingerprint en Python/TS; supuesto: nueva separación]`

Normalización de ZIP: paths POSIX relativos, sin `..`, barra inicial, `\\`, unidades Windows, symlinks o duplicaciones (también case-insensitive); orden bytewise fijo, fecha ZIP válida fija, permisos y flags estables; LF para texto de templates y preservación exacta de assets binarios. Límites de tamaño total/número de archivos; no scripts postinstall. `[supuesto]`

## Consecuencias y trade-offs

El proyecto se puede generar en navegador o API sin subprocess Python; más superficie en TS (ZIP y plantillas) pero un solo contrato para UI/CLI/API. La CLI Zig offline futura necesitará un ejecutor Zig fiel al **plan serializado**, no una segunda implementación del resolvedor. `[supuesto]`

## Validación y reversa

Comparación *byte por byte* para dos generaciones equivalentes, fixtures golden y test de compilación real de ZIP extraído con Zig 0.17.1; SSR/hidratación sin regresión. Reversa: flag temporal hacia generador Python congelado y revertir PR F2; no borrar golden existentes antes de probar. `[supuesto]`
