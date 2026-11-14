import { createMemo, createSignal, For, onMount, Show } from "solid-js";
import catalog from "../../lib/components.generated.json";
import "./components.css";

type Component = (typeof catalog.components)[number];
const items = catalog.components as Component[];
const demoCounts = Array.from({ length: 52 * 7 }, (_, day) => {
  const base = (day * 17 + Math.floor(day / 7) * 13 + (day * day) % 19) % 23;
  return day % 13 === 0 || day % 31 === 0 ? 0 : base;
});

type Appearance = "graphite" | "light" | "contrast";
type Accent = "lavender" | "mint" | "coral" | "sky" | "amber";
const accents: Accent[] = ["lavender", "mint", "coral", "sky", "amber"];
const categories = ["All", ...new Set(items.map((i) => i.category))];

function Icon(props: { name: "chevron" | "search" | "copy" | "check" | "grid" | "external" }) {
  const shape = () => {
    switch (props.name) {
      case "chevron": return <path d="m9 18 6-6-6-6" />;
      case "search": return <><circle cx="11" cy="11" r="7" /><path d="m16 16 5 5" /></>;
      case "copy": return <><rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/></>;
      case "check": return <path d="m5 12 4 4L19 6" />;
      case "grid": return <><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></>;
      case "external": return <><path d="M14 3h7v7m0-7L10 14"/><path d="M21 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h6"/></>;
    }
  };
  return <svg aria-hidden="true" width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">{shape()}</svg>;
}

function Preview(props: {
  component: Component;
  appearance: Appearance;
  accent: Accent;
  compact: boolean;
}) {
  const [weeks, setWeeks] = createSignal(16);
  const [selectedDay, setSelectedDay] = createSignal<number | null>(null);
  const [clicks, setClicks] = createSignal(0);
  const [progress, setProgress] = createSignal(64);
  const [calendar, setCalendar] = createSignal({ year: 2026, month: 10 });
  const [pickedDate, setPickedDate] = createSignal("2026-11-14");
  const [fieldValue, setFieldValue] = createSignal("");
  const [showPassword, setShowPassword] = createSignal(false);
  const [notifications, setNotifications] = createSignal(true);
  const [analytics, setAnalytics] = createSignal(false);
  const monthText = () => new Intl.DateTimeFormat("en", { month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(Date.UTC(calendar().year, calendar().month, 1)));
  const calendarGrid = createMemo(() => {
    const { year, month } = calendar();
    const first = (new Date(Date.UTC(year, month, 1)).getUTCDay() + 6) % 7;
    const days = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
    return Array.from({ length: Math.ceil((first + days) / 7) * 7 }, (_, i) => i >= first && i < first + days ? i - first + 1 : null);
  });
  const dateKey = (day: number) => `${calendar().year}-${String(calendar().month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
  const shiftCalendar = (delta: number) => setCalendar(prev => {
    const next = new Date(Date.UTC(prev.year, prev.month + delta, 1));
    return { year: next.getUTCFullYear(), month: next.getUTCMonth() };
  });
  const max = () => Math.max(...demoCounts.slice(0, weeks() * 7));
  const level = (count: number) => count === 0 ? 0 : Math.min(4, Math.ceil(count * 4 / (max() || 1)));
  const cells = createMemo(() => demoCounts.slice(0, weeks() * 7));
  return <div class={`zc-stage theme-${props.appearance} accent-${props.accent}`} classList={{ compact: props.compact }}>
    <SwitchContent />
  </div>;

  function SwitchContent() {
    return <>
      <Show when={props.component.id === "heatmap"}>
        <div class="zc-heatmap-head"><div><strong>Activity overview</strong><span>Contributions in the selected period</span></div><span class="zc-stat">{cells().reduce((sum, n) => sum + n, 0)} events</span></div>
        <div class="zc-mini-control" role="group" aria-label="Weeks to display">
          <For each={[16, 32, 52]}>{(count) => <button type="button" classList={{ active: weeks() === count }} aria-pressed={weeks() === count} onClick={() => { setWeeks(count); setSelectedDay(null); }}>{count} weeks</button>}</For>
        </div>
        <div class="zc-heatmap-scroll"><div class="zc-heatmap-layout">
          <div class="zc-day-labels" aria-hidden="true"><span>Mon</span><span>Wed</span><span>Fri</span></div>
          <div class="zc-heatmap-grid" style={{ "--weeks": weeks() }} role="group" aria-label="Sample activity for each day">
            <For each={cells()}>{(count, index) => <button type="button" class={`zc-cell level-${level(count)}`} classList={{ picked: selectedDay() === index() }}
              aria-label={`Sample day ${index() + 1}: ${count} activities`} aria-pressed={selectedDay() === index()}
              title={`Day ${index() + 1}: ${count} activities`} onClick={() => setSelectedDay(index())}/>}</For>
          </div>
        </div></div>
        <div class="zc-heatmap-footer"><span role="status">{selectedDay() === null ? "Select a day to inspect activity" : `Day ${selectedDay()! + 1} · ${cells()[selectedDay()!] ?? 0} activities`}</span><span class="zc-legend">Less <i class="level-0"/><i class="level-1"/><i class="level-2"/><i class="level-3"/><i class="level-4"/> More</span></div>
      </Show>
      <Show when={props.component.id === "progress"}>
        <div class="zc-preview-centered"><div class="zc-progress-demo"><div class="zc-progress-heading"><span>Importing your library</span><strong>{progress()}%</strong></div><div role="progressbar" aria-valuenow={progress()} aria-valuemin={0} aria-valuemax={100} aria-label="Import progress" class="zc-progress-track"><div style={{width:`${progress()}%`}} class="zc-progress-fill"/></div><p>Determinate progress with a persistent value</p><input aria-label="Change progress" type="range" min="0" max="100" value={progress()} onInput={(e) => setProgress(Number(e.currentTarget.value))}/></div></div>
      </Show>
      <Show when={props.component.id === "action"}>
        <div class="zc-preview-centered"><div class="zc-action-demo"><strong>Semantic actions</strong><p>Primary, secondary, selected and disabled variants</p><div class="zc-action-row"><button class="zc-primary" onClick={() => setClicks(clicks() + 1)}>Save changes</button><button class="zc-secondary" onClick={() => setClicks(clicks() + 1)}>Cancel</button><button class="zc-selected" aria-pressed="true">Selected</button><button class="zc-secondary" disabled>Disabled</button></div><span role="status" class="zc-small-note">{clicks() ? `${clicks()} interactions · web demonstration` : "Try the buttons"}</span></div></div>
      </Show>
      <Show when={props.component.id === "calendar"}>
        <div class="zc-preview-centered"><div class="zc-calendar" aria-label="Interactive sample calendar">
          <div class="zc-calendar-heading"><strong>{monthText()}</strong><div><button type="button" onClick={() => shiftCalendar(-1)} aria-label="Previous month">‹</button><button type="button" onClick={() => shiftCalendar(1)} aria-label="Next month">›</button></div></div>
          <div class="zc-calendar-grid"><For each={["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]}>{day => <span class="zc-calendar-weekday">{day}</span>}</For>
            <For each={calendarGrid()}>{day => day === null ? <span aria-hidden="true"/> : <button type="button" classList={{ selected: pickedDate() === dateKey(day), today: dateKey(day) === "2026-11-14" }} aria-label={dateKey(day)} aria-pressed={pickedDate() === dateKey(day)} onClick={() => setPickedDate(dateKey(day))}>{day}</button>}</For>
          </div><small role="status">Selected: {pickedDate()}</small>
        </div></div>
      </Show>
      <Show when={props.component.id === "input"}>
        <div class="zc-preview-centered"><div class="zc-form-demo"><strong>Text input</strong><p>Native DVUI owns editing; the app owns the buffer.</p>
          <label for="zc-example-name">Project name</label><input id="zc-example-name" type="text" placeholder="Your project" value={fieldValue()} onInput={e => setFieldValue(e.currentTarget.value)} />
          <label for="zc-example-secret">Password</label><div class="zc-password-row"><input id="zc-example-secret" type={showPassword() ? "text" : "password"} placeholder="Secret value"/><button type="button" onClick={() => setShowPassword(!showPassword())}>{showPassword() ? "Hide" : "Show"}</button></div>
          <small role="status">{fieldValue().trim() ? `Hello, ${fieldValue().slice(0, 40)}` : "Type to preview an input state"}</small>
        </div></div>
      </Show>
      <Show when={props.component.id === "checkbox"}>
        <div class="zc-preview-centered"><div class="zc-form-demo"><strong>Checkbox field</strong><p>Values are explicit and owned by your Zig application.</p>
          <label class="zc-checkbox-row"><input type="checkbox" checked={notifications()} onChange={e => setNotifications(e.currentTarget.checked)}/><span><b>Notifications</b><small>Receive updates when your project builds</small></span></label>
          <label class="zc-checkbox-row"><input type="checkbox" checked={analytics()} onChange={e => setAnalytics(e.currentTarget.checked)}/><span><b>Anonymous analytics</b><small>Off by default</small></span></label>
          <small role="status">{notifications() ? "Notifications on" : "Notifications off"} · {analytics() ? "Analytics on" : "Analytics off"}</small>
        </div></div>
      </Show>
      <Show when={props.component.id === "separator"}>
        <div class="zc-preview-centered"><div class="zc-form-demo"><strong>Separator</strong><p>Semantic grouping without a heavy layout dependency.</p><div class="zc-separator-example">Account settings</div><div class="zc-demo-rule"/><div class="zc-separator-example">Profile & preferences</div><div class="zc-demo-rule"/><div class="zc-separator-example">Notifications</div></div></div>
      </Show>
      <Show when={props.component.id === "tokens"}>
        <div class="zc-preview-centered"><div class="zc-token-demo"><strong>Semantic palette</strong><p>One theme configuration, consistent meaning across components</p><div class="zc-swatch-row"><For each={["canvas","surface","elevated","accent","positive","negative"]}>{(name) => <div class="zc-swatch"><i class={`zc-swatch-${name}`}/><span>{name}</span></div>}</For></div></div></div>
      </Show>
    </>;
  }
}

export default function ComponentsPage() {
  // SolidStart renders the shell on the server. Complex preview widgets mount
  // only after the initial hydration pass, so their hydration IDs cannot drift
  // between SSR and the reactive client tree. Avoid toggling this flag earlier.
  const [hydrated, setHydrated] = createSignal(false);
  onMount(() => setHydrated(true));
  const [filter, setFilter] = createSignal("");
  const [category, setCategory] = createSignal("All");
  const [current, setCurrent] = createSignal("heatmap");
  const [appearance, setAppearance] = createSignal<Appearance>("graphite");
  const [accent, setAccent] = createSignal<Accent>("lavender");
  const [compact, setCompact] = createSignal(false);
  const [tab, setTab] = createSignal<"preview" | "code">("preview");
  const [sourceIndex, setSourceIndex] = createSignal(0);
  const [copied, setCopied] = createSignal("");
  const visible = createMemo(() => items.filter((item) => (category() === "All" || item.category === category()) &&
    `${item.name} ${item.category} ${item.description}`.toLowerCase().includes(filter().toLowerCase())));
  const item = createMemo(() => items.find((i) => i.id === current()) ?? items[0]);
  const source = createMemo(() => item().files[Math.min(sourceIndex(), item().files.length - 1)]);
  const install = createMemo(() => `zig run packages/zevui-cli/src/main.zig -- add ${item().id} --project /path/to/your-project`);

  async function copy(value: string, kind: string) {
    try { await navigator.clipboard.writeText(value); setCopied(kind); }
    catch { setCopied(""); }
  }
  function choose(id: string) {
    setCurrent(id); setTab("preview"); setSourceIndex(0); setCopied("");
  }

  return <div class="page-shell components-app">
    <header class="site-header">
      <a class="brand" href="/" aria-label="Zevui Initializr"><span class="brand-icon">Z</span><span class="brand-word">zevui<span class="brand-muted">/components</span></span></a>
      <nav class="top-nav" aria-label="Zevui navigation">
        <a href="/">Initializr <span aria-hidden="true">›</span></a><a aria-current="page" href="/components">Components</a><span class="pill top-version">Zig 0.17.1</span>
      </nav>
    </header>
    <main class="zc-main">
      <section class="zc-hero"><span class="eyebrow"><span class="eyebrow-dot"/> SOURCE-OWNED NATIVE UI</span><h1>Components you own.<br/><em>Interfaces that feel native.</em></h1><p>Discover composable Zig + DVUI components. Preview the design, copy the source, and evolve it in your own application. No browser runtime is shipped to desktop.</p><div class="zc-hero-links"><a href="/">Open Initializr <span aria-hidden="true">›</span></a><span>{items.length} source-owned components</span><span>Zero external UI runtime</span></div></section>
      <Show when={hydrated()} fallback={<div class="zc-boot" role="status" aria-live="polite"><strong>Components library</strong><p>Loading interactive component previews…</p></div>}>
      <div class="zc-layout">
        <aside class="zc-sidebar" aria-label="Component catalog">
          <div class="zc-side-header"><Icon name="grid"/><strong>Library</strong><span>{items.length}</span></div>
          <label class="zc-search"><Icon name="search"/><input type="search" aria-label="Find components" placeholder="Search components..." value={filter()} onInput={(e) => setFilter(e.currentTarget.value)}/></label>
          <div class="zc-side-cats"><For each={categories}>{(c) => <button type="button" classList={{active:category()===c}} aria-pressed={category()===c} onClick={() => setCategory(c)}>{c}</button>}</For></div>
          <div class="zc-side-items"><For each={visible()} fallback={<p class="zc-empty">No matching components</p>}>
            {(c) => <button type="button" classList={{active:current()===c.id}} onClick={() => choose(c.id)}><span>{c.name}</span><small>{c.status === "stable" ? "Stable" : "Preview"}</small></button>}
          </For></div>
          <div class="zc-sidebar-foot"><span>Native by design</span><p>Web previews are illustrative. Zig source is the installable implementation.</p></div>
        </aside>
        <article class="zc-detail">
          <div class="zc-detail-title"><div><span class="zc-path">COMPONENT / {item().category.toUpperCase()}</span><h2>{item().name}</h2><p>{item().description}</p></div><span class="zc-status">{item().status}</span></div>
          <div class="zc-workbench">
            <div class="zc-workbench-head"><div class="zc-tab-list" role="tablist" aria-label="Component presentation"><button role="tab" aria-selected={tab()==="preview"} classList={{active:tab()==="preview"}} onClick={() => setTab("preview")}>Preview</button><button role="tab" aria-selected={tab()==="code"} classList={{active:tab()==="code"}} onClick={() => setTab("code")}>Source</button></div><div class="zc-renderer">{tab()==="preview" ? "Web approximation" : "Zig source"}</div></div>
            <Show when={tab() === "preview"} fallback={<div class="zc-source-panel"><div class="zc-source-toolbar"><div class="zc-files"><For each={item().files}>{(file, idx) => <button classList={{active:sourceIndex()===idx()}} onClick={() => setSourceIndex(idx())}>{file.target.split("/").at(-1)}</button>}</For></div><button class="zc-copy" onClick={() => copy(source().source, "source")}><Icon name={copied()==="source"?"check":"copy"}/>{copied()==="source"?"Copied":"Copy source"}</button></div><pre><code>{source().source}</code></pre></div>}>
              <div class="zc-preview-wrap"><Preview component={item()} appearance={appearance()} accent={accent()} compact={compact()}/></div>
              <div class="zc-controls"><label>Theme <select value={appearance()} onChange={(e) => setAppearance(e.currentTarget.value as Appearance)}><option value="graphite">Graphite</option><option value="light">Light</option><option value="contrast">High contrast</option></select></label><label>Density <select value={compact()?"compact":"comfortable"} onChange={(e) => setCompact(e.currentTarget.value==="compact")}><option value="comfortable">Comfortable</option><option value="compact">Compact</option></select></label><div class="zc-accent-controls" role="group" aria-label="Accent color"><For each={accents}>{(a) => <button type="button" class={`zc-accent-dot dot-${a}`} classList={{active:accent()===a}} aria-label={`Accent ${a}`} aria-pressed={accent()===a} onClick={() => setAccent(a)}/>}</For></div></div>
            </Show>
          </div>
          <div class="zc-lower-grid"><section class="zc-instruction"><div class="zc-instruction-head"><h3>Install to your app</h3><span>Source-first</span></div><p>Run the native Zig CLI from the Zevui repository. After npm publication, use bunx @zevui/cli add instead. Local edits are protected.</p><div class="zc-command"><code>{install()}</code><button aria-label="Copy install command" onClick={() => copy(install(), "install")}><Icon name={copied()==="install"?"check":"copy"}/></button></div><small>Requires Zig 0.17.1 and the DVUI import provided by your project.</small></section><section class="zc-instruction"><div class="zc-instruction-head"><h3>Usage</h3><span>{item().files.length} source files</span></div><pre><code>{item().usage}</code></pre><button class="zc-copy" onClick={() => copy(item().usage,"usage")}><Icon name={copied()==="usage"?"check":"copy"}/>{copied()==="usage"?"Copied":"Copy usage"}</button></section></div>
          <section class="zc-difference"><div><h3>Why source-owned?</h3><p>No mystery dependency: installs are deterministic, checksummed, and visible. Your modifications remain yours; Zevui detects conflicts instead of silently rewriting them.</p></div><a href="https://github.com/david-vanderson/dvui" target="_blank" rel="noopener noreferrer">Built on DVUI <Icon name="external"/></a></section>
        </article>
      </div>
      </Show>
    </main>
    <footer class="footer"><span>© Zevui · Independent components for DVUI</span><span>Preview in HTML · Runtime in native Zig</span></footer>
  </div>;
}
