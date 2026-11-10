'use strict';
const byId = (id) => document.getElementById(id);
const name = byId('name'), org = byId('organization'), title = byId('title');
function update() { byId('preview-title').textContent = title.value || 'Untitled'; byId('preview-id').textContent = `${org.value}.${name.value}`; }
[name, org, title].forEach((e) => e.addEventListener('input', update));
async function loadCatalog() {
  const res = await fetch('/api/catalog'); if (!res.ok) throw new Error('Catalog unavailable');
  const catalog = await res.json();
  for (const addon of catalog.addons) {
    const el = document.createElement('label'); el.className = 'addon';
    const input = document.createElement('input'); input.type = 'checkbox'; input.name = 'addon'; input.value = addon.id;
    input.checked = addon.status === 'available' && addon.default; input.disabled = addon.status !== 'available';
    const block = document.createElement('div'), label = document.createElement('strong'), description = document.createElement('small'), tag = document.createElement('span');
    label.textContent = addon.name; description.textContent = addon.description; tag.textContent = addon.status; tag.className = 'tag';
    block.append(label, description); el.append(input, block, tag); byId('addons').append(el);
  }
}
loadCatalog().catch(e => {byId('status').textContent = String(e);});
byId('form').addEventListener('submit', async (ev) => {
  ev.preventDefault(); const button = byId('generate'); button.disabled = true;
  byId('status').textContent = 'Generating…';
  try {
    const data = {name:name.value,title:title.value,organization:org.value,version:byId('version').value,addons:[...document.querySelectorAll('input[name=addon]:checked')].map(e=>e.value)};
    const resp = await fetch('/api/generate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});
    if (!resp.ok) {const err=await resp.json(); throw new Error(err.error || 'Generation failed');}
    const blob = await resp.blob(); const url = URL.createObjectURL(blob);
    const a = document.createElement('a'); a.href=url; a.download = `${data.name}.zip`; a.click();
    setTimeout(()=>URL.revokeObjectURL(url),1000); byId('status').textContent = 'Project generated. Extract it, then run zig build run.';
  } catch(e) {byId('status').textContent=String(e);} finally {button.disabled=false;}
});
