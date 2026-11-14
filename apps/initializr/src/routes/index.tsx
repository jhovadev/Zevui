import { createMemo, createSignal, For, onMount, Show } from "solid-js";
import type { Addon, Catalog, ProjectRequest } from "../lib/types";
import { validateProject } from "../lib/types";
import { planProject, PlanError } from "../../../../packages/initializr-core/src/index.js";

function Icon(props: { name: "bolt" | "download" | "search" | "check" | "box" | "arrow" | "code" | "layers" | "spark" | "info" | "copy"; size?: number }) {
  const size = props.size ?? 18;
  // Render only the requested SVG shape. Eagerly creating JSX for every
  // icon can perturb Solid's hydration node allocation.
  const shape = () => {
    switch (props.name) {
      case "bolt": return <path d="m13 2-9 12h7l-1 8 10-12h-7l1-8Z" />;
      case "download": return <><path d="M12 3v12m-5-5 5 5 5-5" /><path d="M5 17v3h14v-3" /></>;
      case "search": return <><circle cx="11" cy="11" r="7" /><path d="m16 16 5 5" /></>;
      case "check": return <path d="m5 12 4 4L19 6" />;
      case "box": return <><path d="m3 7 9-5 9 5v10l-9 5-9-5z" /><path d="m3 7 9 5 9-5m-9 5v10" /></>;
      case "arrow": return <path d="M5 12h14m-7-7 7 7-7 7" />;
      case "code": return <><path d="m8 5-6 7 6 7m8-14 6 7-6 7M14 3l-4 18" /></>;
      case "layers": return <><path d="m12 3 9 5-9 5-9-5 9-5Zm-9 9 9 5 9-5M3 16l9 5 9-5" /></>;
      case "spark": return <path d="m12 2 2.5 7.5L22 12l-7.5 2.5L12 22l-2.5-7.5L2 12l7.5-2.5z" />;
      case "info": return <><circle cx="12" cy="12" r="10" /><path d="M12 11v6m0-10v.01" /></>;
      case "copy": return <><rect x="8" y="8" width="12" height="12" rx="2" /><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" /></>;
    }
  };
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">{shape()}</svg>;
}

const defaults: ProjectRequest = {
  name: "my-zevui-app", title: "My Zevui App", organization: "dev.example",
  version: "0.1.0", addons: ["design_tokens"],
};

type Status = "idle" | "generating" | "success" | "error";

export default function Home() {
  const [catalog, setCatalog] = createSignal<Catalog | null>(null);
  const [catalogError, setCatalogError] = createSignal("");
  const [project, setProject] = createSignal<ProjectRequest>({ ...defaults, addons: [...defaults.addons] });
  const [filter, setFilter] = createSignal("");
  const [category, setCategory] = createSignal("Todos");
  const [status, setStatus] = createSignal<Status>("idle");
  const [message, setMessage] = createSignal("");
  const [copied, setCopied] = createSignal(false);
  const [shared, setShared] = createSignal(false);

  onMount(async () => {
    // Browser-only values stay outside SSR to prevent hydration mismatch.
    const params = new URLSearchParams(window.location.search);
    const saved = {
      name: params.get("name") || defaults.name,
      title: params.get("title") || defaults.title,
      organization: params.get("organization") || defaults.organization,
      version: params.get("version") || defaults.version,
      addons: (params.get("addons") ?? defaults.addons.join(",")).split(",").filter(Boolean),
    };
    const requestedId = Number(params.get("fp"));
    const generatedId = crypto.getRandomValues(new Uint32Array(1))[0];
    const fingerprintId = Number.isInteger(requestedId) && requestedId > 0 && requestedId < 0xffffffff
      ? requestedId : generatedId === 0 || generatedId === 0xffffffff ? 1 : generatedId;
    try {
      const response = await fetch("/api/metadata", { cache: "no-store" });
      if (!response.ok) throw new Error("No se pudo cargar el registro de addons.");
      const result: Catalog = await response.json();
      setCatalog(result);
      const activeAddons = params.has("addons") ? saved.addons : result.addons
        .filter((a) => a.default && a.status === "available").map((a) => a.id);
      setProject({ ...saved, addons: activeAddons, fingerprintId });
    } catch (error) { setCatalogError(error instanceof Error ? error.message : "Error de conexión"); }
  });

  const categories = createMemo(() => ["Todos", ...new Set((catalog()?.addons ?? []).map((item) => item.category))]);
  const visible = createMemo(() => (catalog()?.addons ?? []).filter((addon) => {
    const q = filter().trim().toLowerCase();
    return (category() === "Todos" || addon.category === category()) &&
      (!q || `${addon.name} ${addon.description} ${addon.category}`.toLowerCase().includes(q));
  }));
  const selected = createMemo(() => (catalog()?.addons ?? []).filter((addon) => project().addons.includes(addon.id)));
  const invalid = createMemo(() => validateProject(project()));
  const planned = createMemo(() => {
    const c = catalog();
    if (!c || invalid()) return { plan: null, error: null };
    try { return { plan: planProject(project(), c), error: null }; }
    catch (e) { return { plan: null, error: e instanceof PlanError ? e.message : "Configuración inválida" }; }
  });

  function update(field: "name" | "title" | "organization" | "version", value: string) {
    setProject((p) => ({ ...p, [field]: value }));
    if (status() === "error") setStatus("idle");
  }
  function toggle(addon: Addon) {
    if (addon.status !== "available") return;
    setProject((p) => ({ ...p, addons: p.addons.includes(addon.id)
      ? p.addons.filter((id) => id !== addon.id)
      : [...p.addons, addon.id] }));
  }
  async function generate() {
    if (status() === "generating" || invalid() || !planned().plan) return;
    setStatus("generating"); setMessage("");
    try {
      const response = await fetch("/api/generate", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify(project()),
      });
      if (!response.ok) {
        const detail: { error?: string } = await response.json().catch(() => ({}));
        throw new Error(detail.error || `Error ${response.status}`);
      }
      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url; a.download = `${project().name}.zip`;
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setStatus("success"); setMessage("Proyecto generado. Descomprime el ZIP y ejecuta zig build run.");
    } catch (error) {
      setStatus("error"); setMessage(error instanceof Error ? error.message : "No se pudo generar el proyecto");
    }
  }
  async function shareConfig() {
    const p = project();
    const params = new URLSearchParams({ name: p.name, title: p.title,
      organization: p.organization, version: p.version, addons: [...p.addons].sort().join(","),
      fp: String(p.fingerprintId ?? 1) });
    const url = `${location.origin}${location.pathname}?${params.toString()}`;
    history.replaceState(null, "", url);
    try { await navigator.clipboard.writeText(url); setShared(true); }
    catch { setShared(false); }
  }
  async function copyCommand() {
    try {
      await navigator.clipboard.writeText(`cd ${project().name} && zig build run`);
      setCopied(true);
    } catch { setCopied(false); }
  }

  return <div class="page-shell">
    <header class="site-header">
      <a class="brand" href="/" aria-label="Zevui Initializr inicio">
        <span class="brand-icon">Z</span>
        <span class="brand-word">zevui<span class="brand-muted">/initializr</span></span>
      </a>
      <nav class="top-nav" aria-label="Enlaces de proyecto">
        <a href="/components">Components <Icon name="arrow" size={14}/></a>
        <a href="https://github.com/david-vanderson/dvui" target="_blank" rel="noopener noreferrer">DVUI <Icon name="arrow" size={14}/></a>
        <a href="https://github.com/jhovadev/zigdataengine" target="_blank" rel="noopener noreferrer">ZData <Icon name="arrow" size={14}/></a>
        <span class="pill top-version">Zig {catalog()?.zig ?? "0.17.1"}</span>
      </nav>
    </header>

    <main>
      <section class="hero">
        <div class="eyebrow"><span class="eyebrow-dot"/> THE NATIVE ZIG STARTER</div>
        <h1>Build native.<br/><span>Start beautifully.</span></h1>
        <p>Prepara tu aplicación de escritorio con Zig, DVUI y SDL3. Elige los addons que necesitas y genera un proyecto limpio, sin runtime web en el ejecutable.</p>
        <div class="hero-facts">
          <span><Icon name="check" size={15}/> Zig-first</span>
          <span><Icon name="check" size={15}/> Native UI</span>
          <span><Icon name="check" size={15}/> Addons modulares</span>
        </div>
        <a class="hero-components-link" href="/components">Explore Zevui Components <Icon name="arrow" size={15}/></a>
      </section>

      <div class="workspace">
        <div class="workspace-main">
          <section class="panel" aria-labelledby="project-heading">
            <div class="panel-heading">
              <div><span class="step">01</span> <h2 id="project-heading">Configura tu proyecto</h2></div>
              <span class="panel-aside">PROJECT METADATA</span>
            </div>
            <div class="form-grid">
              <label class="field"><span>Nombre del proyecto <strong>*</strong></span>
                <input value={project().name} onInput={(e) => update("name", e.currentTarget.value)} spellcheck={false} autocomplete="off" aria-invalid={!/^[a-z][a-z0-9_-]{1,31}$/.test(project().name)} />
                <small>Se utilizará como carpeta y nombre del paquete Zig.</small>
              </label>
              <label class="field"><span>Nombre visible <strong>*</strong></span>
                <input value={project().title} onInput={(e) => update("title", e.currentTarget.value)} maxlength={80} />
                <small>Título de la ventana de tu aplicación.</small>
              </label>
              <label class="field"><span>Organización <strong>*</strong></span>
                <input value={project().organization} onInput={(e) => update("organization", e.currentTarget.value)} spellcheck={false} />
                <small>Ejemplo: dev.jhovadev</small>
              </label>
              <label class="field"><span>Versión <strong>*</strong></span>
                <input value={project().version} onInput={(e) => update("version", e.currentTarget.value)} spellcheck={false} />
                <small>Versión semántica del proyecto.</small>
              </label>
            </div>
            <Show when={invalid()}><p class="validation" role="alert"><Icon name="info" size={16}/> {invalid()}</p></Show>
            <Show when={planned().error}><p class="validation" role="alert"><Icon name="info" size={16}/> {planned().error}</p></Show>
          </section>

          <section class="panel addons" aria-labelledby="addons-heading">
            <div class="panel-heading">
              <div><span class="step">02</span> <h2 id="addons-heading">Selecciona addons</h2></div>
              <span class="panel-aside">{selected().length} SELECTED</span>
            </div>
            <p class="panel-description">Incluye solo lo que tu aplicación necesita. Los módulos que todavía no están listos aparecen bloqueados para evitar configuraciones incompatibles.</p>
            <div class="addon-tools">
              <label class="addon-search"><Icon name="search" size={18}/><input type="search" placeholder="Buscar addons..." value={filter()} onInput={(e) => setFilter(e.currentTarget.value)} /></label>
              <div class="category-filters" role="group" aria-label="Categorías">
                <For each={categories()}>{(item) => <button type="button" classList={{ active: category() === item }} onClick={() => setCategory(item)}>{item}</button>}</For>
              </div>
            </div>
            <Show when={catalogError()}><div class="notice error" role="alert">{catalogError()} <button type="button" onClick={() => location.reload()}>Reintentar</button></div></Show>
            <div class="addon-grid">
              <For each={visible()} fallback={<div class="empty-addons">No hay addons para esta búsqueda.</div>}>
                {(addon) => <button
                  type="button" class="addon-card" classList={{ chosen: project().addons.includes(addon.id), disabled: addon.status !== "available" }}
                  disabled={addon.status !== "available"} aria-pressed={project().addons.includes(addon.id)} onClick={() => toggle(addon)}>
                  <span class="addon-card-top"><span class="addon-icon"><Icon name={addon.category === "UI" ? "spark" : addon.category === "Storage" || addon.category === "State" ? "layers" : addon.category === "Data" ? "code" : "box"} size={19}/></span><span class="addon-tick"><Show when={project().addons.includes(addon.id)}><Icon name="check" size={14}/></Show></span></span>
                  <span class="addon-title">{addon.name}</span>
                  <span class="addon-description">{addon.description}</span>
                  <span class="addon-bottom"><span class="addon-category">{addon.category}</span><span classList={{ status: true, ready: addon.status === "available" }}>{addon.status === "available" ? "Disponible" : addon.status === "manual" ? "Manual" : "Próximamente"}</span></span>
                </button>}
              </For>
            </div>
          </section>
        </div>

        <aside class="summary" aria-labelledby="summary-heading">
          <div class="summary-inner">
            <div class="summary-header"><span class="summary-icon"><Icon name="box" size={21}/></span><span>PROJECT PREVIEW</span></div>
            <h2 id="summary-heading">Tu starter, listo para crear.</h2>
            <p>Un proyecto Zig compilable con los módulos que tú elijas.</p>
            <div class="summary-info"><div><span>Framework</span><strong>DVUI + SDL3</strong></div><div><span>Lenguaje</span><strong>Zig {catalog()?.zig ?? "0.17.1"}</strong></div><div><span>Build</span><strong>zig build</strong></div></div>
            <div class="summary-addons"><div class="section-label">ADDONS INCLUIDOS <span>{selected().length}</span></div>
              <Show when={selected().length} fallback={<p class="no-addons">Ninguno. Puedes empezar con una aplicación mínima.</p>}>
                <For each={selected()}>{(addon) => <span class="selected-addon"><Icon name="check" size={14}/>{addon.name}<button type="button" onClick={() => toggle(addon)} aria-label={`Quitar ${addon.name}`}>×</button></span>}</For>
              </Show>
            </div>
            <div class="file-preview"><div><span class="terminal-dot"/><span class="terminal-dot"/><span class="terminal-dot"/></div><code>$ zig build run</code><small>DVUI native application</small></div>
            <Show when={planned().plan}>
              {(ready) => <details class="plan-details">
                <summary>Explorar archivos <span>{ready().operations.length} archivos</span></summary>
                <div class="plan-file-list">
                  <For each={ready().operations}>{(entry) => <code>{entry.path}</code>}</For>
                </div>
                <small>DVUI fijado por hash · {ready().resolvedAddons.length} addons resueltos</small>
              </details>}
            </Show>
            <button type="button" class="share-project" onClick={shareConfig}>{shared() ? "Enlace copiado" : "Compartir configuración"}</button>
            <button class="generate" type="button" disabled={status() === "generating" || !planned().plan} onClick={generate}>
              <Icon name="download" size={18}/>{status() === "generating" ? "Generando..." : "Generate project ZIP"}<Icon name="arrow" size={17}/>
            </button>
            <Show when={message()}><div classList={{ notice: true, error: status() === "error", success: status() === "success" }} role="status">{message()}
              <Show when={status() === "success"}><button type="button" onClick={copyCommand}><Icon name="copy" size={15}/>{copied() ? "Copiado" : "Copiar comando"}</button></Show>
            </div></Show>
            <p class="summary-footnote">Se descarga código fuente. El proyecto generado no necesita Node, SolidStart ni Python para compilar.</p>
          </div>
        </aside>
      </div>
    </main>
    <footer class="footer"><span>© Zevui · Built for native Zig apps</span><span>SolidStart powers only this generator. DVUI runs your desktop app.</span></footer>
  </div>;
}
