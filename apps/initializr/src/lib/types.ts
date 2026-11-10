import type { Addon as SharedAddon, Catalog as SharedCatalog, ProjectInput } from "../../../../packages/initializr-core/src/index.js";
export type Addon = SharedAddon;
export type Catalog = SharedCatalog;
export type ProjectRequest = ProjectInput;

export const NAME_RE = /^[a-z][a-z0-9_-]{1,31}$/;
export const ORG_RE = /^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)+$/;
export const VERSION_RE = /^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$/;
export function validateProject(p: ProjectRequest): string | null {
  if (!NAME_RE.test(p.name)) return "Usa 2–32 caracteres: minúsculas, números, _ o -.";
  if (!p.title.trim() || p.title.length > 80 || /[\x00-\x1f]/.test(p.title)) return "El título debe tener entre 1 y 80 caracteres.";
  if (!ORG_RE.test(p.organization)) return "Usa un identificador como dev.miempresa.";
  if (!VERSION_RE.test(p.version)) return "Usa una versión semántica, por ejemplo 0.1.0.";
  if (p.fingerprintId !== undefined && (!Number.isInteger(p.fingerprintId) || p.fingerprintId <= 0 || p.fingerprintId >= 0xffff_ffff)) return "Identificador de paquete Zig no válido.";
  return null;
}
