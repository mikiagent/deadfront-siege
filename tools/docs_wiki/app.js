/* WildLands MMO wiki — vanilla JS, no build step. */
"use strict";
const STATUSES = ["canon", "useful", "stale", "conflict", "review", "archive"];
const ST_LABEL = { canon: "Canon", useful: "Useful", stale: "Stale", conflict: "Conflicting", review: "Needs review", archive: "Archive" };
const LINK_TYPES = ["supersedes", "conflicts", "supports", "duplicate"];
var INDEX = null, STATE = null, CUR = null, CUR_ANCHOR = "", TAB = "browse", SAVE_T = null, OTHER_OPEN = false;
var ARCHIVE_RESULTS = {}, ARCHIVE_TIMER = null, ARCHIVE_SEQUENCE = 0, ARCHIVE_LOADING = false, ARCHIVE_ERROR = "";

const $ = (s) => document.querySelector(s);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const stOf = (key) => (STATE.docs[key] || {}).status || "";
const stSource = (key) => (STATE.docs[key] || {}).by || "";

async function api(path, opts) { const r = await fetch(path, opts); if (!r.ok) throw new Error(path); return r.json(); }
function scheduleSave() { clearTimeout(SAVE_T); SAVE_T = setTimeout(saveState, 400); }
async function saveState() { await api("/api/state", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(STATE) }); }

async function boot() {
  [INDEX, STATE] = await Promise.all([api("/api/index"), api("/api/state")]);
  const params = new URLSearchParams(location.search);
  const hash = new URLSearchParams(location.hash.slice(1));
  const start = hash.get("doc") || params.get("doc");
  document.querySelectorAll("nav button").forEach((b) => (b.onclick = () => setTab(b.dataset.tab)));
  $("#exportBtn").onclick = exportAll;
  setTab("browse");
  $("#q").oninput = searchChanged;
  window.addEventListener("hashchange", () => {
    const route = new URLSearchParams(location.hash.slice(1));
    const key = route.get("doc"), anchor = route.get("anchor") || "";
    if (key && docEntry(key)) { if (key !== CUR || anchor !== CUR_ANCHOR || TAB !== "browse") openDoc(key, false, anchor); }
    else if (!key) { CUR = null; CUR_ANCHOR = ""; setTab("browse"); }
  });
  if (start && docEntry(start)) { openDoc(start, false, hash.get("anchor") || ""); }
  console.log("wiki ready", Object.keys(INDEX.docs).length, "docs");
}

/* ---------- sidebar ---------- */
function archiveCommand() { return /^\/archive(?:\s|$)/i.test($("#q").value.trim()); }
function searchChanged() {
  clearTimeout(ARCHIVE_TIMER);
  const sequence = ++ARCHIVE_SEQUENCE;
  ARCHIVE_RESULTS = {}; ARCHIVE_LOADING = false; ARCHIVE_ERROR = "";
  if (!archiveCommand()) { renderSidebar(); if (TAB === "systems") renderSystems(); return; }
  if (TAB !== "browse") setTab("browse");
  const query = $("#q").value.trim().replace(/^\/archive\s*/i, "").trim();
  if (!query) { renderSidebar(); return; }
  ARCHIVE_LOADING = true; renderSidebar();
  ARCHIVE_TIMER = setTimeout(async () => {
    try {
      const data = await api("/api/archive/search?q=" + encodeURIComponent(query));
      if (sequence !== ARCHIVE_SEQUENCE || !archiveCommand()) return;
      ARCHIVE_RESULTS = Object.fromEntries((data.results || []).filter((d) => d.key?.startsWith("main:")).map((d) => [d.key, d]));
    } catch (_) {
      if (sequence !== ARCHIVE_SEQUENCE || !archiveCommand()) return;
      ARCHIVE_ERROR = "Archive search failed. Please try again.";
    }
    ARCHIVE_LOADING = false; renderSidebar();
  }, 250);
}

function visibleDocs() {
  const q = $("#q").value.trim().toLowerCase();
  const out = [];
  for (const key of Object.keys(INDEX.docs)) {
    const d = INDEX.docs[key];
    if (d.deep) continue;
    if (!q) { out.push(key); continue; }
    const hay = (d.title + " " + d.path + " " + d.system).toLowerCase();
    if (hay.includes(q)) out.push(key);
  }
  return out;
}

function renderSidebar() {
  const el = $("#sidebar");
  if (archiveCommand()) {
    const term = $("#q").value.trim().replace(/^\/archive\s*/i, "").trim();
    const results = Object.values(ARCHIVE_RESULTS);
    const message = !term ? "Enter a search term after /archive." : ARCHIVE_LOADING ? "Searching archive…" : ARCHIVE_ERROR || (results.length ? `${results.length} archive results` : "No archive results.");
    el.innerHTML = `<div class="badge" role="status">${esc(message)}</div>` + results.map((d) => `<button class="doc" data-archive-key="${escAttr(d.key)}"><span class="t"><b>${esc(d.title)}</b><br><span class="badge">${esc(d.path)}</span>${d.excerpt ? `<br><span class="badge">${esc(d.excerpt)}</span>` : ""}</span></button>`).join("");
    el.querySelectorAll("[data-archive-key]").forEach((button) => { button.onclick = () => openDoc(button.dataset.archiveKey); });
    return;
  }
  const keys = visibleDocs();
  const groups = {};
  if (TAB === "systems") {
    for (const k of keys) { const g = INDEX.docs[k].system; (groups[g] = groups[g] || []).push(k); }
  } else {
    for (const k of keys) { const d = INDEX.docs[k]; const group = docCategory(d); (groups[group] = groups[group] || []).push(k); }
  }
  const gOrder = Object.keys(groups).sort((a, b) => ["Current implementation", "Vision", "Other documents", "Archive"].indexOf(a) - ["Current implementation", "Vision", "Other documents", "Archive"].indexOf(b));
  let html = "";
  for (const g of gOrder) {
    const skeys = groups[g].sort((a, b) => INDEX.docs[a].title.localeCompare(INDEX.docs[b].title));
    html += g === "Other documents" ? `<details id="otherDocs" ${OTHER_OPEN ? "open" : ""}><summary class="group">${esc(g)} <span style="opacity:.6">${skeys.length}</span></summary>` : `<div class="group">${esc(g)} <span style="opacity:.6">${skeys.length}</span></div>`;
    for (const k of skeys) {
      const d = INDEX.docs[k]; const st = stOf(k);
      const seed = st && stSource(k) === "seed" ? " seed" : "";
      html += `<button class="doc ${CUR === k ? "on" : ""}" data-key="${esc(k)}" onclick="openDoc('${escAttr(k)}')">
        <span class="t" title="${escAttr(d.path)}">${esc(d.title)}</span>
        ${st ? `<span class="st ${st}${seed}">${ST_LABEL[st]}</span>` : ""}
      </button>`;
    }
    if (g === "Other documents") html += "</details>";
  }
  el.innerHTML = `<div class="badge">${keys.length} documents · archive excluded</div>` + (html || `<p class="badge">No matching documents.</p>`);
  const other = el.querySelector("#otherDocs");
  if (other) other.addEventListener("toggle", () => { OTHER_OPEN = other.open; });
}
const escAttr = (s) => esc(s).replace(/'/g, "&#39;");
function docCategory(d) {
  if (d.deep) return "Archive";
  if (d.path.startsWith("docs/current/")) return "Current implementation";
  if (d.path.startsWith("docs/vision/")) return "Vision";
  return "Other documents";
}

function renderHome() {
  const cards = [
    ["Current implementation", "What the build does today, with paths back to the code and data.", "docs/current/"],
    ["Vision", "The intended experience, confirmed rules, and proposals for future development.", "docs/vision/"],
  ];
  $("#pane").innerHTML = `<div class="eyebrow">WildLands MMO · project documentation</div><h1>Welcome to the WildLands MMO Wiki</h1>
    <div class="article-tabs"><span>Overview</span></div>
    <div class="home-intro"><h2>One project, two perspectives</h2><p>Explore the game as it exists today and the vision guiding what comes next. Historical documents are available separately in the archive.</p></div>
    <div class="home-grid">${cards.map(([title, desc, prefix]) => {
      const keys = Object.keys(INDEX.docs).filter((k) => INDEX.docs[k].line === "canon" && INDEX.docs[k].path.startsWith(prefix));
      keys.sort((a, b) => (INDEX.docs[a].path.endsWith("README.md") ? -1 : 0) - (INDEX.docs[b].path.endsWith("README.md") ? -1 : 0) || INDEX.docs[a].title.localeCompare(INDEX.docs[b].title));
      return `<section class="home-card"><h3>${title}</h3><p>${desc}</p>${keys.map((k) => `<button class="home-link" onclick="openDoc('${escAttr(k)}')">${esc(INDEX.docs[k].title)}</button>`).join("")}</section>`;
    }).join("")}</div>
    <h2>Working with the wiki</h2><p>Search document titles and paths above, browse by system, or use the canon map and reconcile queue to organize sources. To search historical documents intentionally, enter <b>/archive</b> followed by a search term.</p>
    <p><button class="home-link" onclick="openDoc('canon:docs/agent-context.md')">Agent entry point</button><button class="home-link" onclick="openDoc('canon:docs/wiki-maintenance.md')">Wiki maintenance guide for people and agents</button></p>`;
}

/* ---------- doc view ---------- */
function docRoute(key, anchor = "") {
  const route = new URLSearchParams({ doc: key });
  if (anchor) route.set("anchor", anchor);
  return "#" + route.toString();
}

function docEntry(key) {
  if (INDEX.docs[key]) return INDEX.docs[key];
  if (ARCHIVE_RESULTS[key]) return ARCHIVE_RESULTS[key];
  if (key?.startsWith("main:")) {
    const path = key.slice(5);
    return { key, line: "main", deep: true, path, title: path.split("/").pop(), size: 0, date: "", banner: false, fallback: true };
  }
  return null;
}

async function openDoc(key, curationOpen = false, anchor = "") {
  const e = docEntry(key);
  if (!e) return;
  TAB = "browse";
  document.querySelectorAll("nav button").forEach((b) => b.classList.toggle("on", b.dataset.tab === "browse"));
  $("#sidebar").classList.remove("hidden");
  CUR = key; CUR_ANCHOR = anchor; location.hash = docRoute(key, anchor);
  renderSidebar();
  const pane = $("#pane");
  pane.innerHTML = `<div class="meta">${esc(e.line)}:${esc(e.path)}</div><h2 style="opacity:.5">loading…</h2>`;
  let text;
  try {
    const res = await fetch("/api/doc?key=" + encodeURIComponent(key));
    if (!res.ok) throw new Error(`Server returned ${res.status}`);
    text = await res.text();
  } catch (error) {
    if (CUR === key && TAB === "browse") pane.innerHTML = `<div class="notice" role="alert">Could not load this ${e.deep ? "archived " : ""}document: ${esc(error.message)}. ${e.deep ? "It may have moved or no longer be available in the archive checkout." : "Please try again."}</div>`;
    return;
  }
  if (CUR !== key || CUR_ANCHOR !== anchor || TAB !== "browse") return;
  if (e.fallback) {
    const title = text.split("\n").slice(0, 12).find((line) => line.startsWith("# "));
    if (title) e.title = title.slice(2).trim();
    e.size = new TextEncoder().encode(text).length;
  }
  const inbound = INDEX.inbound[key] || 0, broken = INDEX.broken[key] || 0;
  const hints = [];
  if (e.banner) hints.push("superseded banner");
  if (e.date) hints.push(`last dated ${e.date}`);
  if (broken) hints.push(`${broken} broken link${broken > 1 ? "s" : ""}`);
  if (!e.deep) hints.push(`${inbound} inbound link${inbound === 1 ? "" : "s"}`);
  if (e.line === "main" && INDEX.cross_line_diffs.includes(e.path)) hints.push("DIFFERS from the canon-line copy");
  const my = STATE.docs[key] || (STATE.docs[key] = { status: "", notes: "", links: [] });
  const rel = my.links || (my.links = []);
  const paths = Object.keys(INDEX.docs).filter((k) => k !== key);
  pane.innerHTML = `
    <div class="eyebrow">${esc(docCategory(e))}</div>
    <h1>${esc(e.title)}</h1>
    <div class="article-tabs"><span>Article</span></div>
    <div class="meta">
      <span>${esc(docCategory(e))}</span>
      <span>${esc(e.path)}</span>
      <span>· ${(e.size / 1024).toFixed(1)} KB</span>
      <span>· ${hints.map((h) => `<span class="hintchip">${esc(h)}</span>`).join(" ")}</span>
    </div>
    <div class="md" id="body"></div>
    <details class="curation" ${curationOpen ? "open" : ""}><summary>Document curation · status, notes and relationships</summary>
    <div class="statusbar">
      <span class="badge">status:</span>
      ${STATUSES.map((s) => `<button data-st="${s}" class="${my.status === s ? "on" : ""}">${ST_LABEL[s]}</button>`).join("")}
      <button data-st="" class="${my.status ? "" : "on"}">Clear${my.by === "seed" ? " (suggested → confirm/remove)" : ""}</button>
    </div>
    ${my.by === "seed" && my.notes ? `<div class="notice">Seeded note: ${esc(my.notes)} — set the status yourself to confirm it.</div>` : ""}
    <div class="row" style="margin:8px 0">
      <input type="text" id="linkSel" list="doclist" placeholder="Connect a doc… (line:path)" style="flex:1;min-width:240px">
      <select id="linkType">${LINK_TYPES.map((t) => `<option>${t}</option>`).join("")}</select>
      <button class="btn" id="addLink">Add link</button>
      <datalist id="doclist">${[...new Set(paths)].sort().map((p) => `<option value="${escAttr(p)}"></option>`).join("")}</datalist>
    </div>
    <div id="links"></div>
    <textarea id="notes" aria-label="Curation notes" placeholder="Your notes (why stale/canon, what to check…)">${esc(my.notes || "")}</textarea></details>`;
  pane.querySelector(".statusbar").onclick = (ev) => {
    const b = ev.target.closest("button[data-st]"); if (!b) return;
    const s = b.dataset.st;
    if (s) { my.status = s; my.by = "user"; delete my.notes_note; } else { my.status = ""; }
    STATE.docs[key] = my;
    scheduleSave(); openDoc(key, true, CUR_ANCHOR);
  };
  const drawLinks = () => {
    const el = pane.querySelector("#links");
    el.innerHTML = rel.length ? rel.map((l, i) =>
      `<div class="row"><span class="st ${l.type === "conflicts" ? "conflict" : "useful"}">${esc(l.type)}</span>
        <button class="home-link" data-rel="${i}">${esc(l.path)}</button>
        <button class="btn small danger" data-i="${i}">✕</button></div>`).join("")
      : `<div class="badge">no links marked yet</div>`;
    el.querySelectorAll("button[data-rel]").forEach((b) => (b.onclick = () => openDocByPath(rel[+b.dataset.rel].path, e.line)));
    el.querySelectorAll("button[data-i]").forEach((b) => (b.onclick = () => { rel.splice(+b.dataset.i, 1); scheduleSave(); drawLinks(); }));
  };
  pane.querySelector("#addLink").onclick = () => {
    const p = resolveDocKey(pane.querySelector("#linkSel").value.trim(), e.line); const t = pane.querySelector("#linkType").value;
    if (!p || !paths.includes(p)) { pane.querySelector("#linkSel").value = ""; return; }
    if (rel.some((l) => resolveDocKey(l.path, e.line) === p && l.type === t)) return;
    rel.push({ path: p, type: t });
    if (t === "conflicts") createTask(key, p);
    scheduleSave(); drawLinks(); pane.querySelector("#linkSel").value = "";
  };
  drawLinks();
  pane.querySelector("#notes").oninput = (ev) => { my.notes = ev.target.value; scheduleSave(); };
  const body = pane.querySelector("#body");
  if (window.marked) body.innerHTML = marked.parse(text);
  else body.innerHTML = `<pre>${esc(text)}</pre>`;
  const headingCounts = new Map();
  body.querySelectorAll("h1,h2,h3,h4,h5,h6").forEach((heading) => {
    const slug = heading.textContent.trim().toLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu, "").replace(/\s+/g, "-");
    const count = headingCounts.get(slug) || 0;
    headingCounts.set(slug, count + 1);
    heading.id = slug + (count ? `-${count}` : "");
  });
  // Relative images (docs/current/screens) load through /api/image, resolved against the doc.
  body.querySelectorAll("img[src]").forEach((img) => {
    const src = img.getAttribute("src");
    if (/^(?:[a-z][a-z0-9+.-]*:|\/)/i.test(src)) return;
    const base = e.path.includes("/") ? e.path.slice(0, e.path.lastIndexOf("/") + 1) : "";
    img.src = "/api/image?path=" + encodeURIComponent(norm(base + src));
    img.loading = "lazy";
  });
  body.querySelectorAll("a[href]").forEach((a) => {
    const href = a.getAttribute("href");
    if (/^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(href)) return;
    const parts = href.split("#", 2);
    const path = parts[0];
    if (path && !/\.md$/i.test(path)) return;
    const base = e.path.includes("/") ? e.path.slice(0, e.path.lastIndexOf("/") + 1) : "";
    let resolved, fragment;
    try { resolved = path ? norm((path.startsWith("/") ? "" : base) + decodeURIComponent(path)) : e.path; fragment = decodeURIComponent(parts[1] || ""); }
    catch (_) { return; }
    const hit = resolveDocKey(`${e.line}:${resolved}`);
    if (!hit) return;
    a.setAttribute("href", docRoute(hit, fragment));
    a.onclick = (ev) => { if (ev.button !== 0 || ev.metaKey || ev.ctrlKey || ev.shiftKey || ev.altKey) return; ev.preventDefault(); openDoc(hit, false, fragment); };
  });
  if (anchor) [...body.querySelectorAll("h1,h2,h3,h4,h5,h6")].find((heading) => heading.id === anchor)?.scrollIntoView();
}
const norm = (p) => { const out = []; for (const seg of p.split("/")) { if (seg === "..") out.pop(); else if (seg && seg !== ".") out.push(seg); } return out.join("/"); };
function resolveDocKey(value, preferredLine = "") {
  if (INDEX.docs[value]) return value;
  if (typeof value === "string" && value.startsWith("main:")) return value;
  if (preferredLine === "main" && typeof value === "string" && value && !value.includes(":")) return `main:${value}`;
  if (preferredLine && INDEX.docs[`${preferredLine}:${value}`]) return `${preferredLine}:${value}`;
  const matches = Object.keys(INDEX.docs).filter((k) => INDEX.docs[k].path === value);
  return matches.length === 1 ? matches[0] : null;
}
function openDocByPath(p, preferredLine = "") {
  const hit = resolveDocKey(p, preferredLine);
  if (hit) openDoc(hit);
}

/* ---------- reconcile ---------- */
function taskKey(a, b) { return [a, b].sort().join("||"); }
function createTask(a, b) {
  const first = resolveDocKey(a), second = resolveDocKey(b, INDEX.docs[first]?.line);
  if (first && second && !STATE.tasks.some((t) => {
    const oldFirst = resolveDocKey(t.a), oldSecond = resolveDocKey(t.b, INDEX.docs[oldFirst]?.line);
    return oldFirst && oldSecond && taskKey(oldFirst, oldSecond) === taskKey(first, second);
  })) {
    STATE.tasks.push({ id: taskKey(first, second), a: first, b: second, open: true, question: "", answer: "" });
    scheduleSave();
  }
  updateReconcileCount();
}
function updateReconcileCount() {
  const n = STATE.tasks.filter((t) => t.open).length;
  $("#reconcileCount").textContent = n || "";
}
function renderReconcile() {
  const pane = $("#pane");
  let html = `<h2>Reconcile queue</h2>
    <p class="badge">Mark conflicts on a doc (Connect a doc… → conflicts) to create a task. Existing archive references remain in saved tasks.</p>`;
  html += `<div class="card"><div class="group" style="margin-top:0">manual tasks (${STATE.tasks.length})</div>` +
    (STATE.tasks.length ? STATE.tasks.map((t) => taskCard(t)).join("") : "<div class='badge'>none yet</div>") + `</div>`;
  pane.innerHTML = html;
  wireTaskCards(pane);
}
function taskCard(t) {
  const first = resolveDocKey(t.a);
  const keys = [first, resolveDocKey(t.b, INDEX.docs[first]?.line)];
  const chips = [t.a, t.b].map((value, i) => value ? (keys[i] ? `<button class="home-link" data-task-doc="${i}">${esc(keys[i])}</button>` : `<span class="warn">${esc(value)} (not found or ambiguous)</span>`) : "").filter(Boolean).join(" <b>vs</b> ");
  return `<div class="card hint" data-id="${escAttr(t.id)}">
    <div class="row">${chips}<span style="flex:1"></span>
      <label class="badge"><input type="checkbox" data-done ${t.open ? "" : "checked"}> resolved</label>
      <button class="btn small danger" data-del>delete</button></div>
    <textarea data-q placeholder="What to reconcile (the question to settle):">${esc(t.question || "")}</textarea>
    <textarea data-ans placeholder="Decision / updated wording:">${esc(t.answer || "")}</textarea>
  </div>`;
}
function wireTaskCards(pane) {
  pane.querySelectorAll(".card.hint[data-id]").forEach((el) => {
    const t = STATE.tasks.find((x) => x.id === el.dataset.id); if (!t) return;
    el.querySelectorAll("[data-task-doc]").forEach((button) => { button.onclick = () => {
      const first = resolveDocKey(t.a), target = button.dataset.taskDoc === "0" ? first : resolveDocKey(t.b, INDEX.docs[first]?.line);
      if (target) openDoc(target);
    }; });
    el.querySelector("[data-q]").oninput = (e) => { t.question = e.target.value; scheduleSave(); };
    el.querySelector("[data-ans]").oninput = (e) => { t.answer = e.target.value; scheduleSave(); };
    el.querySelector("[data-done]").onchange = (e) => { t.open = !e.target.checked; scheduleSave(); updateReconcileCount(); };
    el.querySelector("[data-del]").onclick = () => { STATE.tasks = STATE.tasks.filter((x) => x !== t); scheduleSave(); updateReconcileCount(); renderReconcile(); };
  });
}
/* ---------- systems ---------- */
function renderSystems() {
  const pane = $("#pane");
  const q = $("#q").value.trim().toLowerCase();
  let html = `<h2>Systems</h2><p class="badge">The game outline. Each card = one system with its docs; set statuses inside or open a doc to work on it.</p><div class="sysgrid">`;
  for (const sys of Object.keys(INDEX.systems).sort()) {
    const keys = INDEX.systems[sys].filter((k) => {
      if (INDEX.docs[k].deep) return false;
      if (!q) return true;
      const d = INDEX.docs[k]; return (d.title + " " + d.path).toLowerCase().includes(q);
    });
    if (!keys.length) continue;
    html += `<div class="card"><div class="group" style="margin-top:0">${esc(sys)} (${keys.length})</div>` +
      keys.map((k) => {
        const d = INDEX.docs[k]; const st = stOf(k); const seed = st && stSource(k) === "seed" ? " seed" : "";
        return `<button class="row doc" style="margin:2px 0" onclick="openDoc('${escAttr(k)}')">
          <span class="line ${d.line}">${esc(docCategory(d))}</span>
          <span class="t">${esc(d.title)}</span>${st ? `<span class="st ${st}${seed}">${ST_LABEL[st]}</span>` : ""}</button>`;
      }).join("") + `</div>`;
  }
  pane.innerHTML = html + `</div>`;
}

/* ---------- map ---------- */
function renderMap() {
  const pane = $("#pane");
  const assigned = STATE.map || [];
  const used = new Set(assigned.reduce((a, s) => a.concat(s.docs), []));
  let html = `<h2>Canon map (the context map)</h2>
    <p class="badge">The low-context entry point: per system, which doc is the current truth. Add docs from the picker; Export writes canon-map.md for sessions to read instead of every file.</p>`;
  for (const s of assigned) {
    html += `<div class="card" data-sid="${escAttr(s.id)}">
      <div class="row"><input type="text" data-sname value="${escAttr(s.name)}" style="font-weight:600;max-width:260px">
        <span style="flex:1"></span><button class="btn small danger" data-sdel>remove section</button></div>
      ${s.docs.map((k) => mapRow(k)).join("")}
      <div class="row"><input type="text" data-spick list="doclist" placeholder="assign a doc…" style="flex:1"></div>
    </div>`;
  }
  const available = Object.keys(INDEX.docs).filter((k) => !INDEX.docs[k].deep);
  html += `<div class="card hint"><div class="row"><button class="btn" id="addSection">+ add section</button>
    <span style="flex:1"></span><button class="btn" id="autoseed">Auto-outline from index</button></div></div>
    <datalist id="doclist">${available.sort((a, b) => INDEX.docs[a].path.localeCompare(INDEX.docs[b].path)).map((k) => `<option value="${escAttr(k)}"></option>`).join("")}</datalist>
    <details style="margin-top:14px"><summary>docs not yet mapped (${available.filter((k) => !used.has(k)).length})</summary>
      <div class="sysgrid" style="margin-top:10px">${available.filter((k) => !used.has(k)).map((k) =>
    `<div class="row doc" onclick="openDoc('${escAttr(k)}')"><span class="t">${esc(INDEX.docs[k].path)}</span></div>`).join("")}</div>
    </details>`;
  pane.innerHTML = html;
  pane.querySelectorAll("[data-sname]").forEach((el) => { el.oninput = () => { sec(el).name = el.value; scheduleSave(); }; });
  pane.querySelectorAll("[data-sdel]").forEach((el) => { el.onclick = () => { STATE.map = STATE.map.filter((s) => s.id !== sec(el).id); scheduleSave(); renderMap(); updateReconcileCount(); }; });
  pane.querySelectorAll("[data-spick]").forEach((el) => {
    el.onchange = () => { const s = sec(el); if (el.value && INDEX.docs[el.value] && !s.docs.includes(el.value)) { s.docs.push(el.value); scheduleSave(); renderMap(); } };
  });
  pane.querySelector("#addSection").onclick = () => { STATE.map = STATE.map || []; STATE.map.push({ id: "S" + Date.now(), name: "New section", docs: [] }); scheduleSave(); renderMap(); };
  pane.querySelector("#autoseed").onclick = () => { STATE.map = autoMapSeed(); scheduleSave(); renderMap(); };
  function sec(el) { return STATE.map.find((s) => s.id === el.closest(".card").dataset.sid); }
  function mapRow(k) {
    if (!INDEX.docs[k]) return `<div class="row warn">${k.startsWith("main:") ? "Archive reference (excluded from normal index)" : "Missing document"}: ${esc(k)}</div>`;
    const d = INDEX.docs[k]; const st = stOf(k); const seed = st && stSource(k) === "seed" ? " seed" : "";
    return `<div class="row doc" onclick="openDoc('${escAttr(k)}')">
      <span class="line ${d.line}">${d.line}</span><span class="t">${esc(d.path)}</span>
      ${st ? `<span class="st ${st}${seed}">${ST_LABEL[st]}</span>` : `<span class="st review">unmarked</span>`}
      <span style="flex:1"></span><button class="btn small danger" data-un="${escAttr(k)}">✕</button></div>`;
  }
  pane.querySelectorAll("[data-un]").forEach((b) => b.onclick = (ev) => {
    ev.stopPropagation();
    const s = STATE.map.find((x) => x.id === b.closest(".card").dataset.sid);
    s.docs = s.docs.filter((d) => d !== b.dataset.un); scheduleSave(); renderMap();
  });
}
const MAP_SECTIONS = [
  ["Vision & positioning", ["prd", "vision", "mki-", "gdd"]],
  ["World, islands & biomes", ["island", "world", "biome", "climate"]],
  ["Inventory & items", ["inventory", "item", "trait", "rarity"]],
  ["Crafting & cooking", ["craft", "cook", "food", "recipe"]],
  ["Skills", ["skill"]],
  ["Creatures, AI & combat", ["creature", "ai", "combat", "bestiar"]],
  ["Taming, pets & mounts", ["tame", "pet", "mount"]],
  ["Economy & trading", ["economy", "market", "trade"]],
  ["Multiplayer & server", ["server", "multiplayer", "contract", "mmo"]],
  ["UI & UX", ["ui", "ux", "hud"]],
  ["Art & asset pipeline", ["style", "concept-art", "benchmark", "rig", "asset"]],
  ["Save & persistence", ["save", "persistent", "schema"]],
  ["Survival needs", ["hunger", "water", "fatigue", "needs", "sleep"]],
  ["Story & objectives", ["story", "objective", "quest"]],
  ["Protocol (per-session rules)", ["handoff", "gauntlet", "agents"]],
];
function autoMapSeed() {
  const out = [];
  for (const [name, tokens] of MAP_SECTIONS) {
    const docs = [];
    for (const k of Object.keys(INDEX.docs).sort((a, b) => INDEX.docs[b].date.localeCompare(INDEX.docs[a].date))) {
      if (INDEX.docs[k].deep) continue;
      const p = INDEX.docs[k].path.toLowerCase() + " " + INDEX.docs[k].system.toLowerCase();
      if (tokens.some((t) => p.includes(t)) && docs.length < 6) docs.push(k);
    }
    if (docs.length) out.push({ id: "S" + name.replace(/\W/g, ""), name, docs });
  }
  return out;
}

/* ---------- export ---------- */
function exportAll() {
  const line = (s) => s + "\n";
  let md = line("# WildLands MMO canon map");
  md += line("");
  md += line(`_Generated from the docs wiki on ${new Date().toISOString().slice(0, 10)}; statuses marked by the owner in tools/docs_wiki._`);
  md += line("");
  md += line(`Canon line: ${INDEX.canon_root || "unknown"} (claude/mmo-overhaul). Main checkout is archive.`);
  for (const s of STATE.map || []) {
    md += line(`\n## ${s.name}`);
    if (!s.docs.length) { md += line("_empty_"); continue; }
    for (const k of s.docs) {
      const d = INDEX.docs[k] || { line: "?", path: k, title: k };
      const my = STATE.docs[k] || {};
      md += line(`- **${d.path}** (${d.line}${my.status ? ", " + my.status + (my.by === "seed" ? " suggested" : "") : ", unmarked"})${my.notes ? " — " + my.notes.replace(/\n/g, " ") : ""}`);
    }
  }
  const by = {};
  for (const [k, v] of Object.entries(STATE.docs)) by[v.status] = (by[v.status] || 0) + 1;
  md += line("\n## Status tally");
  for (const s of STATUSES) if (by[s]) md += line(`- ${s}: ${by[s]}`);
  const open = (STATE.tasks || []).filter((t) => t.open);
  if (open.length) {
    md += line("\n## Reconcile questions (open)");
    open.forEach((t, i) => {
      md += line(`\n### REC-${String(i + 1).padStart(2, "0")}`);
      t.b ? md += line(`- Pair: ${t.a} **⇄** ${t.b}`) : md += line(`- Doc: ${t.a}`);
      md += line(`- Question: ${t.question || "(unsettled)"}`);
      md += line(`- Decision: ${t.answer || "(none yet)"}`);
    });
  }
  const blob = new Blob([md], { type: "text/markdown" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob); a.download = "canon-map.md"; a.click();
  const s2 = document.createElement("a");
  s2.href = URL.createObjectURL(new Blob([JSON.stringify(STATE, null, 1)], { type: "application/json" }));
  s2.download = "docs_wiki_state.json"; s2.click();
}

/* ---------- phase map ---------- */
const PHASE_STATUS = ["done", "next", "later", "decided-against"];
let PHASE = null;
const phaseCollapsed = {};

async function postPhaseMark(id, status, note) {
  const r = await fetch("/api/phase", { method: "POST", headers: { "Content-Type": "application/json" },
                                        body: JSON.stringify({ id, status, note: note || "" }) });
  if (!r.ok) throw new Error((await r.text()) || r.statusText);
  return r.json();
}

function allPhaseFeatures() { return (PHASE.phases || []).flatMap((p) => p.features); }

function renderPhase(pane) {
  const busyPane = pane && pane.isConnected && pane.querySelector("#phase-root");
  const draw = () => {
    if (TAB === "phase") renderPhase(pane);
  };
  if (!PHASE) {
    if (!busyPane) pane.innerHTML = '<div class="notice">Loading the phase map…</div>';
    api("/api/phase").then((d) => { PHASE = d; for (const p of d.phases) phaseCollapsed[p.phase] = true; draw(); },
                          (e) => { if (TAB === "phase") pane.innerHTML = `<div class="warn">The phase map could not load: ${esc(String(e && e.message || e))}</div>`; });
    return;
  }
  const map = new Map(allPhaseFeatures().map((f) => [f.id, f]));
  const counts = { done: 0, next: 0, later: 0, "decided-against": 0 };
  for (const f of allPhaseFeatures()) counts[f.status]++;
  const nextReady = allPhaseFeatures().filter((f) => f.status === "next" && f.depends.every((d) => (map.get(d) || {}).status === "done"));
  const nextWaiting = allPhaseFeatures().filter((f) => f.status === "next" && !f.depends.every((d) => (map.get(d) || {}).status === "done"));
  const markCount = Object.keys(PHASE.marks || {}).length;
  const phases = [...PHASE.phases].sort((a, b) => a.phase - b.phase);
  const allCollapsed = phases.every((p) => phaseCollapsed[p.phase]);
  const depTag = (depIds) => depIds.map((d) => {
    const f = map.get(d);
    if (!f) return "";
    const cls = f.status === "done" ? "dep done" : "dep";
    return `<a class="${cls}" href="#phase-${esc(f.id)}" title="${esc(f.title)}">${esc(f.title)}</a>`;
  }).join("");  const rows = (phase) => phase.features.map((f) => {
    const blocked = f.depends.some((d) => (map.get(d) || {}).status !== "done");
    const statusCls = f.status === "next" && blocked ? " status next blocked" : ` status ${f.status}`;
    return `<div class="phase-feat" id="phase-${esc(f.id)}">
      <div class="feat-top ${statusCls}">
        ${f.by === "mark" ? '<button class="unmark" data-unmark="' + esc(f.id) + '" title="Reset to the authored status">↺</button>' : ""}
        <select class="phase-select" data-mark="${esc(f.id)}" aria-label="Status of ${esc(f.title)}">
          ${PHASE_STATUS.map((s) => `<option value="${s}" data-label="Status — ${s}"${s === f.status ? " selected" : ""}>${s}</option>`).join("")}
        </select>
        <span class="feat-title">${esc(f.title)}</span>
      </div>
      <div class="feat-meta">
        ${f.depends.length ? `<div class="feat-deps"><span>relies on</span> ${depTag(f.depends)}${f.status === "next" && blocked ? '<span class="blocked-note">blocked</span>' : ""}</div>` : ""}
        ${f.source ? `<a class="feat-src" href="/?doc=${encodeURIComponent(docKeyFor(f.source))}">${esc(f.source)}</a>` : ""}
        ${f.evidence && f.evidence.length ? `<div class="feat-evidence"><span>evidence</span> ${f.evidence.map((e) => /^(https:|commit:)/.test(e) ? `<code>${esc(e)}</code>` : `<a class="feat-src" href="/?doc=${encodeURIComponent(docKeyFor(e))}">${esc(e)}</a>`).join(" ")}</div>` : (f.status === "done" ? '<div class="feat-evidence dim">no evidence linked</div>' : "")}
        ${f.note ? `<div class="feat-note">${esc(f.note)}${f.seed_note ? `<details class="seed-note"><summary>authored note</summary>${esc(f.seed_note)}</details>` : ""}</div>` : ""}
      </div>
    </div>`;
  }).join("");
  pane.innerHTML = `
    <h1>Roadmap</h1>
    <div class="article-lead">${esc(PHASE.goal)}</div>
    <div class="meta">
      <span class="hintchip">Phase 0 first — foundations; polish and tuning sit at the bottom</span>
      <span class="hintchip">${counts.done} done</span>
      <span class="hintchip">${counts.next} next</span>
      <span class="hintchip">${counts.later} later</span>
      ${counts["decided-against"] ? `<span class="hintchip">${counts["decided-against"]} decided against</span>` : ""}
      ${PHASE.updated ? `<span class="hintchip">seeded ${esc(PHASE.updated)}</span>` : ""}
      ${markCount ? `<span class="hintchip">${markCount} personally corrected</span>` : ""}
      ${phases.length ? `<button class="btn small" id="phaseAll">${allCollapsed ? "Expand all" : "Collapse all"}</button>` : ""}
      <span class="hintchip">collapsed by default — headers expand</span>
    </div>
    <div class="phase-next card">
      <h2>Next up</h2>
      ${nextReady.length ? `<ul>${nextReady.map((f) => `<li><strong>${esc(f.title)}</strong>${f.depends.length ? ` <span class="dim">— deps cleared</span>` : ""}</li>`).join("")}</ul>` : '<p class="dim">Nothing "next" has all of its dependencies done yet.</p>'}
      ${nextWaiting.length ? `<p class="dim">Waiting on unfinished deps: ${nextWaiting.map((f) => esc(f.title)).join("; ")}</p>` : ""}
      ${markCount ? '<p class="badge">Statuses corrected here are stored as marks; the phase-map.json file keeps the authored structure and is safe to edit by hand.</p>' : "<p class=\"badge\">Change any status with its dropdown; the authored seed survives underneath.</p>"}
    </div>
    <div class="phase-stack">
      ${phases.map((p) => {
        const meaningful = p.features.filter((f) => f.status !== "decided-against");
        const done = meaningful.filter((f) => f.status === "done").length;
        const pct = meaningful.length ? Math.round((done / meaningful.length) * 100) : 0;
        return `<details class="phase-block" id="phase-block-${p.phase}" data-phase="${p.phase}"${phaseCollapsed[p.phase] ? "" : " open"}>
          <summary class="phase-head">
            <span class="phase-chev" aria-hidden="true"></span>
            <span class="phase-num">Phase ${p.phase}</span>
            <strong>${esc(p.title)}</strong>
            <span class="phase-bar" title="${done} of ${meaningful.length} non-retired features done"><span style="width:${pct}%"></span></span>
            <span class="dim">${done}/${meaningful.length}</span>
          </summary>
          <div class="phase-body">
            <p class="phase-theme">${esc(p.theme || "")}</p>
            ${rows(p)}
          </div>
        </details>`;
      }).join("")}
    </div>`;
  pane.querySelectorAll("select.phase-select").forEach((sel) => {
    sel.onchange = async () => {
      const id = sel.dataset.mark, value = sel.value;
      sel.disabled = true;
      try {
        await postPhaseMark(id, value);
        const f = map.get(id);
        if (f) { f.status = value; if (f.by !== "mark") { f.by = "mark"; PHASE.marks[id] = { status: value, note: f.note || "" }; } else PHASE.marks[id].status = value; }
        draw();
      } catch (e) { sel.disabled = false; sel.value = map.get(id) ? map.get(id).status : sel.value; pane.querySelector("#phase-next").insertAdjacentHTML("afterend", `<div class="warn">Could not save the status: ${esc(String(e && e.message || e))}</div>`); }
    };
  });
  pane.querySelectorAll("button.unmark").forEach((btn) => {
    btn.onclick = async () => {
      const id = btn.dataset.unmark;
      btn.disabled = true;
      try {
        await postPhaseMark(id, "");
        delete PHASE.marks[id];
        const f = map.get(id);
        if (f) delete f.by;
        draw();
      } catch (e) { btn.disabled = false; }
    };
  });
  pane.querySelectorAll("details.phase-block").forEach((det) => {
    det.addEventListener("toggle", () => {
      if (det.open) delete phaseCollapsed[det.dataset.phase];
      else phaseCollapsed[det.dataset.phase] = true;
    });
  });
  const allBtn = pane.querySelector("#phaseAll");
  if (allBtn) allBtn.onclick = () => {
    if (allCollapsed) phases.forEach((p) => delete phaseCollapsed[p.phase]);
    else phases.forEach((p) => { phaseCollapsed[p.phase] = true; });
    draw();
  };
  const phaseOf = new Map();
  for (const p of phases) for (const f of p.features) phaseOf.set(f.id, p.phase);
  pane.querySelectorAll("a.dep").forEach((a) => {
    a.onclick = (ev) => {
      if (ev.button !== 0 || ev.metaKey || ev.ctrlKey || ev.shiftKey || ev.altKey) return;
      ev.preventDefault();
      const id = (a.getAttribute("href") || "").replace(/^#phase-/, "");
      const targetPhase = phaseOf.get(id);
      if (targetPhase == null) return;
      delete phaseCollapsed[targetPhase];
      draw();
      const row = pane.querySelector(`#phase-${CSS.escape(id)}`);
      if (row) row.scrollIntoView({ block: "start", behavior: "smooth" });
    };
  });
}

function docKeyFor(source) {
  const docs = (INDEX && INDEX.docs) || {};
  const hit = Object.entries(docs).find(([, e]) => (e.path || "") === source);
  return hit ? hit[0] : "";
}

/* ---------- tabs ---------- */
function setTab(t) {
  TAB = t;
  document.querySelectorAll("nav button").forEach((b) => b.classList.toggle("on", b.dataset.tab === t));
  if (t === "browse") { $("#sidebar").classList.remove("hidden"); renderSidebar(); renderDocRest(); }
  if (t === "systems") { $("#sidebar").classList.add("hidden"); renderSystems(); }
  if (t === "reconcile") { $("#sidebar").classList.add("hidden"); renderReconcile(); }
  if (t === "map") { $("#sidebar").classList.add("hidden"); if (!STATE.map) STATE.map = autoMapSeed(); renderMap(); }
  if (t === "phase") { $("#sidebar").classList.add("hidden"); renderPhase($("#pane")); }
  if (t === "tuning") { $("#sidebar").classList.add("hidden"); renderTuning($("#pane")); }
  if (t === "plan") { $("#sidebar").classList.add("hidden"); renderPlanReview($("#pane")); }
  if (["art", "ui", "screenshots"].includes(t)) { $("#sidebar").classList.add("hidden"); renderVisionBoard(t, $("#pane")); }
  updateReconcileCount();
}
function renderDocRest() { if (CUR) openDoc(CUR, false, CUR_ANCHOR); else renderHome(); }

boot();
