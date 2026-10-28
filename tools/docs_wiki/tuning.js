/* Owner tuning proposals. The server supplies read-only sheet snapshots. */
'use strict';
(() => {
  const storageKey = 'wildlands-wiki-tuning-drafts-v1';
  let sheet = null, drafts = {}, page = 0, filter = '', persistenceError = '', requestId = 0;
  const pageSize = 50;
  const escapeHtml = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  try { drafts = JSON.parse(localStorage.getItem(storageKey) || '{}'); if (!drafts || typeof drafts !== 'object' || Array.isArray(drafts)) drafts = {}; }
  catch (_) { persistenceError = 'Saved drafts could not be read. Export any changes before closing this page.'; drafts = {}; }
  const saveDrafts = () => { try { localStorage.setItem(storageKey, JSON.stringify(drafts)); persistenceError = ''; } catch (_) { persistenceError = 'This browser could not save your drafts. Export changes before closing the page.'; } };
  const changes = draft => Object.values(draft?.changes || {});
  const totalChanges = () => Object.values(drafts).reduce((n, draft) => n + changes(draft).length, 0);
  const activeDraft = () => drafts[sheet.name];
  const stale = () => activeDraft() && activeDraft().revision !== sheet.revision;
  const download = (name, text) => { const a = document.createElement('a'); const url = URL.createObjectURL(new Blob([text], {type:'application/json'})); a.href = url; a.download = name; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); };
  function exportDrafts() {
    const sheets = Object.entries(drafts).filter(([,d]) => changes(d).length).map(([name,d]) => ({name, kind:d.kind || 'csv', source_path:d.source_path || `game/data_sheets/${name}`, source_revision_sha256:d.revision, changes:changes(d).sort((a,b) => a.row_index-b.row_index || a.column_index-b.column_index)}));
    if (!sheets.length) return;
    const invalid = sheets.flatMap(s => s.changes.map(c => ({s, c}))).find(({c}) => (c.value_type === 'integer' && (!/^-?(?:0|[1-9]\d*)$/.test(c.after.trim()) || !Number.isSafeInteger(Number(c.after)))) || (c.value_type === 'number' && (!/^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$/.test(c.after.trim()) || !Number.isFinite(Number(c.after)))) || (c.operation === 'rename_key' && !c.after.trim()));
    if (invalid) { alert(`Check ${invalid.s.name}, ${invalid.c.row_key}: enter a valid ${invalid.c.value_type === 'integer' ? 'integer' : invalid.c.value_type === 'number' ? 'number' : 'trait name'} before exporting.`); return; }
    download('wildlands-tuning-proposal.json', JSON.stringify({format:'wildlands-tuning-proposal/v1', exported_at:new Date().toISOString(), purpose:'Proposed edits to CSV sheet snapshots. Review against the recorded revision before applying to game data.', sheets}, null, 2) + '\n');
  }
  const getJson = async url => { const r = await fetch(url); if (!r.ok) throw new Error(`Server returned ${r.status}`); return r.json(); };
  async function loadSheet(name, pane) {
    const id = ++requestId;
    pane.querySelector('#tuning-content').innerHTML = '<p>Loading sheet…</p>';
    try { const loaded = await getJson('/api/sheet?name=' + encodeURIComponent(name)); if (id !== requestId || !pane.querySelector('#tuning-content')) return; sheet = loaded; page = 0; filter = ''; draw(pane); }
    catch (err) { if (id === requestId && pane.querySelector('#tuning-content')) pane.querySelector('#tuning-content').innerHTML = `<p class="notice" role="alert">Could not load this sheet: ${escapeHtml(err.message)}</p>`; }
  }
  function draw(pane) {
    if (!sheet || !pane.isConnected) return;
    const d = activeDraft(), isStale = stale();
    const matching = sheet.rows.map((row, index) => ({row,index})).filter(({row}) => !filter || row.some(cell => String(cell).toLowerCase().includes(filter.toLowerCase())));
    const lastPage = Math.max(0, Math.ceil(matching.length / pageSize) - 1); page = Math.min(page, lastPage);
    const entries = matching.slice(page * pageSize, (page + 1) * pageSize);
    const content = pane.querySelector('#tuning-content');
    content.innerHTML = `
      <div class="tuning-sheet-heading"><div><h2>${escapeHtml(sheet.kind === 'trait-map' ? 'Traits · names and documented effects' : sheet.name)}</h2><p class="badge">${escapeHtml(sheet.source_path || sheet.name)} · ${sheet.rows.length} rows · Sheet revision ${escapeHtml(sheet.revision.slice(0,12))}</p></div>
      <label>Filter rows <input id="tuning-filter" type="search" value="${escapeHtml(filter)}" placeholder="Find an item or value"></label></div>
      ${isStale ? '<div class="notice tuning-warning" role="alert">The source sheet changed since this draft was started. Export the draft for review or discard this sheet’s draft before editing again.</div>' : ''}
      ${sheet.kind === 'trait-map' ? '<div class="notice">These are descriptions in the game data, not proof that every effect is implemented. Renaming a trait also requires checking its references.</div>' : ''}
      ${persistenceError ? `<div class="notice tuning-warning" role="alert">${escapeHtml(persistenceError)}</div>` : ''}
      <div class="tuning-controls"><span id="tuning-count">${changes(d).length} proposed changes in this sheet · ${totalChanges()} total</span><button class="btn" id="tuning-export" ${totalChanges() ? '' : 'disabled'}>Export proposed diff</button><button class="btn" id="tuning-clear" ${changes(d).length ? '' : 'disabled'}>Discard this sheet’s draft</button></div>
      <div class="tuning-table-wrap"><table class="tuning-table"><thead><tr>${sheet.columns.map(c=>`<th scope="col">${escapeHtml(c)}</th>`).join('')}</tr></thead><tbody>${entries.map(({row,index}) => `<tr>${sheet.columns.map((col,ci) => {
        const id = index + ':' + ci, edited = d?.changes?.[id], val = edited ? edited.after : (row[ci] ?? '');
        const editable = sheet.editable_columns ? sheet.editable_columns.includes(col) : ci !== 0;
        if (ci === 0) return `<th scope="row">${escapeHtml(val)}</th>`;
        if (!editable) return `<td class="tuning-readonly">${escapeHtml(val)}</td>`;
        return `<td><input data-row="${index}" data-col="${ci}" aria-label="${escapeHtml(row[0])}, ${escapeHtml(col)}, row ${index + 1}" value="${escapeHtml(val)}" class="${edited ? 'changed' : ''}" ${isStale ? 'disabled' : ''}></td>`;
      }).join('')}</tr>`).join('')}</tbody></table></div>
      ${matching.length ? `<div class="tuning-pages"><button class="btn" id="tuning-prev" ${page === 0 ? 'disabled' : ''}>Previous</button><span>Rows ${page * pageSize + 1}–${Math.min((page + 1) * pageSize, matching.length)} of ${matching.length}</span><button class="btn" id="tuning-next" ${page >= lastPage ? 'disabled' : ''}>Next</button></div>` : '<p>No rows match this filter.</p>'}`;
    content.querySelector('#tuning-filter').oninput = e => { filter = e.target.value; page = 0; const caret = e.target.selectionStart; draw(pane); const field = pane.querySelector('#tuning-filter'); field.focus(); field.setSelectionRange(caret, caret); };
    content.querySelector('#tuning-export').onclick = exportDrafts;
    content.querySelector('#tuning-clear').onclick = () => { if (confirm('Discard the proposed changes for this sheet?')) { delete drafts[sheet.name]; saveDrafts(); draw(pane); } };
    content.querySelector('#tuning-prev')?.addEventListener('click', () => { page--; draw(pane); });
    content.querySelector('#tuning-next')?.addEventListener('click', () => { page++; draw(pane); });
    content.querySelectorAll('input[data-row]').forEach(input => input.addEventListener('input', () => {
      const ri = Number(input.dataset.row), ci = Number(input.dataset.col), id = ri + ':' + ci, before = sheet.rows[ri][ci] ?? '';
      if (!drafts[sheet.name]) drafts[sheet.name] = {revision:sheet.revision, kind:sheet.kind || 'csv', source_path:sheet.source_path || `game/data_sheets/${sheet.name}`, changes:{}};
      const current = drafts[sheet.name];
      if (input.value === before) delete current.changes[id];
      else current.changes[id] = {row_index:ri, row_key:sheet.rows[ri][0], column_index:ci, column:sheet.columns[ci], operation:sheet.kind === 'trait-map' && sheet.columns[ci] === 'trait name' ? 'rename_key' : 'set_value', value_type:sheet.kind === 'json' ? sheet.rows[ri][1] : sheet.kind === 'trait-map' ? 'string' : 'csv-cell', before, after:input.value};
      if (!changes(current).length) delete drafts[sheet.name];
      saveDrafts(); input.classList.toggle('changed', input.value !== before);
      content.querySelector('#tuning-count').textContent = `${changes(activeDraft()).length} proposed changes in this sheet · ${totalChanges()} total`;
      content.querySelector('#tuning-export').disabled = !totalChanges(); content.querySelector('#tuning-clear').disabled = !changes(activeDraft()).length;
      let notice = content.querySelector('#tuning-save-error');
      if (persistenceError && !notice) { notice = document.createElement('p'); notice.id = 'tuning-save-error'; notice.className = 'notice tuning-warning'; notice.setAttribute('role','alert'); content.querySelector('.tuning-controls').after(notice); }
      if (notice) { notice.textContent = persistenceError; notice.hidden = !persistenceError; }
    }));
  }
  window.renderTuning = async pane => {
    pane.innerHTML = `<div class="eyebrow">Tuning workshop</div><h1>Gameplay tuning sheets</h1><div class="article-tabs"><span>Proposals</span></div>
      <p class="article-lead">Edit a sheet to explore changes. Drafts stay in this browser and the exported diff records the original and proposed values. Game data does not change until an agent reviews and applies the proposal.</p>
      <div class="notice">These sheets cover part of the game data, not every gameplay setting. CSV sheets may include edits not yet applied to the build. Parameter sheets show source JSON values. Identifiers and type labels are read-only. Proposals need type, range and reference checks before application.</div>
      <label class="tuning-selector">Sheet <select id="tuning-select" aria-label="Choose a tuning sheet"></select></label><div id="tuning-content"><p>Loading sheets…</p></div>`;
    try {
      const result = await getJson('/api/sheets');
      if (!pane.isConnected || document.querySelector('#pane') !== pane || !pane.querySelector('#tuning-select')) return;
      const select = pane.querySelector('#tuning-select');
      select.innerHTML = result.sheets.map(s => `<option value="${escapeHtml(s.name)}">${escapeHtml(s.kind === 'trait-map' ? 'Traits · names and documented effects' : s.kind === 'json' ? 'Parameters · ' + s.source_path : s.name)} (${s.row_count})</option>`).join('');
      if (!result.sheets.length) { pane.querySelector('#tuning-content').innerHTML = '<p>No sheets are available.</p>'; return; }
      select.onchange = () => loadSheet(select.value, pane);
      await loadSheet(result.sheets.some(s => s.name === sheet?.name) ? sheet.name : result.sheets[0].name, pane);
      if (sheet) select.value = sheet.name;
    } catch (err) { if (pane.querySelector('#tuning-content')) pane.querySelector('#tuning-content').innerHTML = `<p class="notice" role="alert">Could not load sheets: ${escapeHtml(err.message)}</p>`; }
  };
})();
