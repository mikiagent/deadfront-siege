/* Plan review: upload/paste, ask questions, review exact vision edits. */
(function () {
  'use strict';
  const maxBytes = 100000;
  const state = { plan: '', filename: '', result: null, answers: {}, decisions: [], busy: false, error: '', message: '', accepted: {}, applied: {}, refactorPath: '', refactor: null };
  let requestNumber = 0;
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const validRoot = pane => pane && pane.isConnected && pane.querySelector('#plan-review');
  const isVision = path => typeof path === 'string' && /^docs\/vision\/[^/]+\.md$/.test(path);
  const sourceList = sources => (Array.isArray(sources) ? sources : []).map(s => {
    const path = String(s.path || ''), line = Number.isInteger(s.line_start) ? `:${s.line_start}${Number.isInteger(s.line_end) && s.line_end !== s.line_start ? '–' + s.line_end : ''}` : '';
    const label = esc(path + line);
    const details = Array.isArray(s.excerpts) && s.excerpts.length ? `<details><summary>View excerpts used</summary>${s.excerpts.map(x => `<p class="badge">Lines ${esc(x.line_start)}–${esc(x.line_end)}</p><blockquote>${esc(x.excerpt)}</blockquote>`).join('')}</details>` : '';
    return `<li>${/^docs\/(current|vision)\//.test(path) ? `<button class="plan-source" type="button" data-source="${esc(path)}">${label}</button>` : `<code>${label}</code>`}${s.excerpt ? `<blockquote>${esc(s.excerpt)}</blockquote>` : ''}${details}</li>`;
  }).join('');
  async function call(path, data) {
    const response = await fetch(path, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(data)});
    const type = response.headers.get('content-type') || '';
    let value = type.includes('application/json') ? await response.json() : await response.text();
    if (!response.ok) throw new Error((value && typeof value === 'object' && (value.error || value.message)) || (typeof value === 'string' && value) || `Server returned ${response.status}`);
    return value;
  }
  function setPlan(text, filename) {
    state.plan = text; state.filename = filename || ''; state.result = null; state.answers = {}; state.decisions = []; state.accepted = {}; state.applied = {}; state.error = ''; state.message = '';
    requestNumber++;
  }
  async function loadFile(file, pane) {
    if (!file) return;
    if (!/\.(md|markdown)$/i.test(file.name)) { state.error = 'Choose a Markdown file ending in .md or .markdown.'; draw(pane); return; }
    if (file.size > maxBytes) { state.error = 'The file is too large. Use a plan up to 100 KB.'; draw(pane); return; }
    try { setPlan(await file.text(), file.name); } catch (_) { state.error = 'The file could not be read. Try pasting its text.'; }
    draw(pane);
  }
  async function analyze(pane, withAnswers) {
    if (state.busy) return;
    const plan = state.plan.trim();
    if (!plan) { state.error = 'Paste a plan or drop in a Markdown file first.'; draw(pane); return; }
    if (new TextEncoder().encode(state.plan).length > maxBytes) { state.error = 'The plan is too large. Use a plan up to 100 KB.'; draw(pane); return; }
    let answers = [];
    if (withAnswers) {
      const questions = Array.isArray(state.result?.questions) ? state.result.questions : [];
      const newAnswers = questions.map(q => ({question_id:String(q.id || ''), question:String(q.question || ''), answer:String(state.answers[q.id] || '').trim()}));
      if (newAnswers.some(a => !a.answer)) { state.error = 'Answer every question before requesting a revised proposal.'; draw(pane); return; }
      answers = [...state.decisions, ...newAnswers];
    }
    const number = ++requestNumber;
    state.busy = true; state.error = ''; state.message = ''; draw(pane);
    try {
      const result = await call('/api/plan/analyze', {plan:state.plan, answers});
      if (number !== requestNumber) return;
      if (!result || !Array.isArray(result.questions) || !Array.isArray(result.edits) || !Array.isArray(result.sources)) throw new Error('The analysis returned an invalid response. Your plan has not been changed.');
      state.result = result; state.decisions = answers; state.answers = {}; state.accepted = {}; state.applied = {};
    } catch (error) { if (number === requestNumber) state.error = String(error.message || error); }
    finally { if (number === requestNumber) { state.busy = false; if (validRoot(pane)) draw(pane); } }
  }
  async function apply(pane, index) {
    const group = state.result?.edits?.[index];
    if (state.busy || !group || !state.accepted[index] || state.result.questions.length || !isVision(group.path)) return;
    const number = ++requestNumber;
    state.busy = true; state.error = ''; state.message = ''; draw(pane);
    try {
      const result = await call('/api/plan/apply', {path:group.path, base_sha256:group.base_sha256, edits:group.edits});
      if (number !== requestNumber) return;
      if (!result || result.ok !== true || result.path !== group.path) throw new Error('The server did not confirm the save. Check the document before trying again.');
      state.applied[index] = true; state.message = `${group.path} saved. Other proposals have not been applied.`;
    } catch (error) { if (number === requestNumber) state.error = String(error.message || error); }
    finally { if (number === requestNumber) { state.busy = false; if (validRoot(pane)) draw(pane); } }
  }
  async function proposeRefactor(pane) {
    if (state.busy || !isVision(state.refactorPath)) return;
    const number = ++requestNumber;
    state.busy = true; state.error = ''; state.message = ''; state.refactor = null; refactorArmed = false; draw(pane);
    try {
      const result = await call('/api/plan/refactor', {path:state.refactorPath});
      if (number !== requestNumber) return;
      if (!result || !Array.isArray(result.sections) || typeof result.index_preview !== 'string') throw new Error('The server returned an invalid structure proposal.');
      state.refactor = result;
    } catch (error) { if (number === requestNumber) state.error = String(error.message || error); }
    finally { if (number === requestNumber) { state.busy = false; if (validRoot(pane)) draw(pane); } }
  }
  async function applyRefactor(pane) {
    if (state.busy || !state.refactor) return;
    const doc = state.refactor;
    const number = ++requestNumber;
    state.busy = true; state.error = ''; state.message = ''; draw(pane);
    try {
      const result = await call('/api/plan/refactor', {path:doc.source_path, action:'apply', proposal:doc});
      if (number !== requestNumber) return;
      if (!result || result.ok !== true) throw new Error('The server did not confirm the split. Check the document before trying again.');
      state.refactor = null; refactorArmed = false;
      state.message = `Split applied: ${result.sections_written} section files written and ${result.source_path} became the review index. The untouched original is backed up at ${result.backup}. Review incoming links from other documents before relying on the new file names.`;
    } catch (error) { if (number === requestNumber) state.error = String(error.message || error); }
    finally { if (number === requestNumber) { state.busy = false; if (validRoot(pane)) draw(pane); } }
  }
  let refactorArmed = false;
  function exportProposal() {
    const text = JSON.stringify({format:'wildlands-plan-review/v1',plan:state.plan,decisions:state.decisions,unsubmitted_answers:state.answers,review:state.result}, null, 2);
    const url = URL.createObjectURL(new Blob([text],{type:'application/json'})), a = document.createElement('a');
    a.href = url; a.download = 'wildlands-plan-review.json'; a.click(); setTimeout(() => URL.revokeObjectURL(url),1000);
  }
  function draw(pane) {
    if (!pane || !pane.isConnected) return;
    const result = state.result, qs = Array.isArray(result?.questions) ? result.questions : [], groups = Array.isArray(result?.edits) ? result.edits : [];
    const visionDocs = Object.values(window.INDEX?.docs || {}).filter(d => d.line === 'canon' && isVision(d.path) && !d.path.endsWith('/README.md')).sort((a,b) => a.path.localeCompare(b.path));
    if (!state.refactorPath && visionDocs.length) state.refactorPath = visionDocs[0].path;
    pane.innerHTML = `<div id="plan-review"><div class="eyebrow">Wildlands MMO · planning</div><h1>Review a plan</h1><div class="article-tabs"><span>Plan reconciliation</span></div>
      <p class="article-lead">Compare a plan with the live vision and current documentation. Answer any conflict questions, then review each proposed vision edit before saving it.</p>
      <div class="notice">Analysis uses the configured AI service and sends it your plan and selected project excerpts. It does not change documents. Current implementation is evidence, and is not rewritten to match future plans.</div>
      <section class="plan-input"><h2>1. Add your plan</h2><div class="plan-drop" id="plan-drop" tabindex="0" role="button" aria-label="Choose or drop a Markdown file"><strong>Drop a Markdown file here</strong><span>or choose a file, or paste the text below</span><input id="plan-file" type="file" accept=".md,.markdown,text/markdown" aria-label="Choose a Markdown file"></div>
      <label for="plan-text">Plan Markdown ${state.filename ? `<span class="badge">${esc(state.filename)}</span>` : ''}</label><textarea id="plan-text" spellcheck="false" placeholder="Paste your plan here…" ${state.busy ? 'disabled' : ''}>${esc(state.plan)}</textarea>
      <div class="plan-actions"><button class="btn plan-primary" id="plan-analyze" ${state.busy ? 'disabled' : ''}>${state.busy ? 'Working…' : 'Analyze plan'}</button><span class="badge">Up to 100 KB. Keep this tab open while working.</span></div></section>
      ${state.error ? `<p role="alert" class="notice plan-error">${esc(state.error)}</p>` : ''}${state.message ? `<p role="status" class="notice">${esc(state.message)}</p>` : ''}
      ${state.busy ? '<p role="status" class="plan-progress">Working with the AI service. This can take a little while…</p>' : ''}
      ${result ? `<section id="plan-result-questions"><h2>2. Questions and evidence</h2>${qs.length ? `<p>These points need your decision before the proposed changes can be applied.</p>${qs.map((q,i) => `<div class="plan-card"><h3>${esc(q.question || `Question ${i+1}`)}</h3>${q.reason ? `<p>${esc(q.reason)}</p>` : ''}${q.sources?.length ? `<ul class="plan-sources">${sourceList(q.sources)}</ul>` : ''}<label for="plan-answer-${i}">Your answer</label><textarea id="plan-answer-${i}" data-answer-index="${i}" ${state.busy ? 'disabled' : ''}>${esc(state.answers[q.id] || '')}</textarea></div>`).join('')}<button class="btn plan-primary" id="plan-refine" ${state.busy ? 'disabled' : ''}>Review my answers</button>` : '<p>No unresolved questions were returned. Check the cited sources and proposals before applying anything.</p>'}
      ${Array.isArray(result.notes) && result.notes.length ? `<h3>Analysis notes</h3><ul>${result.notes.map(n => `<li>${esc(n)}</li>`).join('')}</ul>` : ''}
      ${Array.isArray(result.structure_suggestions) && result.structure_suggestions.length ? `<h3>AI-suggested restructuring</h3><p>These are suggestions for review. Partial excerpts cannot establish that a split or shorter version preserves every decision.</p><ul>${result.structure_suggestions.map(n => `<li>${esc(n)}</li>`).join('')}</ul>` : ''}
      ${result.sources.length ? `<details><summary>Sources consulted (${result.sources.length})</summary><ul class="plan-sources">${sourceList(result.sources)}</ul></details>` : ''}</section>
      <section id="plan-result-edits"><h2>3. Proposed line edits</h2>${qs.length ? '<p class="notice">Answer the questions above and request a revised proposal before applying edits.</p>' : ''}${groups.length ? groups.map((g,i) => {
        const valid = isVision(g.path) && typeof g.base_sha256 === 'string' && /^[a-f0-9]{64}$/i.test(g.base_sha256) && Array.isArray(g.edits) && g.edits.length > 0 && g.edits.every(e => typeof e.old_text === 'string' && e.old_text && typeof e.new_text === 'string');
        return `<article class="plan-card"><h3>${esc(g.path)}</h3>${g.reason ? `<p>${esc(g.reason)}</p>` : ''}<p class="badge">Based on revision ${esc((g.base_sha256 || '').slice(0,12))}</p>${Array.isArray(g.edits) ? g.edits.map((edit,j) => `<div class="plan-diff"><h4>Change ${j+1}${Number.isInteger(edit.line_start) ? ` · line ${edit.line_start}${Number.isInteger(edit.line_end) && edit.line_end !== edit.line_start ? '–' + edit.line_end : ''}` : ''}</h4><div class="plan-before"><span>Current text</span><pre>${esc(edit.old_text)}</pre></div><div class="plan-after"><span>Proposed text</span><pre>${esc(edit.new_text)}</pre></div></div>`).join('') : ''}
        ${!valid ? '<p class="plan-error">This proposal cannot be applied automatically. Review the source and ask an agent to handle it.</p>' : state.applied[i] ? '<p role="status">Saved to the vision document.</p>' : `<label class="plan-check"><input type="checkbox" data-approve="${i}" ${state.accepted[i] ? 'checked' : ''} ${qs.length || state.busy ? 'disabled' : ''}> I reviewed these exact edits to ${esc(g.path)}.</label><button class="btn" data-apply="${i}" ${qs.length || state.busy || !state.accepted[i] ? 'disabled' : ''}>Apply reviewed edits</button>`}</article>`;
      }).join('') : '<p>No line edits were proposed.</p>'}<button class="btn" id="plan-export">Export review as JSON</button></section>` : ''}
      <section id="plan-structure"><h2>Review document structure</h2><p>Preview a split of a long vision document into linked sections. Review the proposed structure and semantics before moving content. This preview changes no files.</p>
      ${visionDocs.length ? `<label for="plan-refactor-doc">Vision document</label><select id="plan-refactor-doc" ${state.busy ? 'disabled' : ''}>${visionDocs.map(d => `<option value="${esc(d.path)}" ${state.refactorPath === d.path ? 'selected' : ''}>${esc(d.title || d.path)}</option>`).join('')}</select><button class="btn" id="plan-refactor" ${state.busy ? 'disabled' : ''}>Preview structure</button>` : '<p>No vision documents are available.</p>'}
      ${state.refactor ? `<div class="plan-card"><h3>Structure preview · ${esc(state.refactor.source_path)}</h3><p class="badge">Revision ${esc(String(state.refactor.source_revision || '').slice(0,12))} · ${state.refactor.sections.length} sections · no files changed</p>${Array.isArray(state.refactor.warnings) && state.refactor.warnings.length ? `<ul>${state.refactor.warnings.map(w => `<li>${esc(w)}</li>`).join('')}</ul>` : ''}<ul>${state.refactor.sections.map(s => `<li>${esc(s.title)} · lines ${esc(s.start_line)}–${esc(s.end_line)} → <code>${esc(s.path)}</code></li>`).join('')}</ul><details><summary>Proposed index</summary><pre class="plan-outline">${esc(state.refactor.index_preview)}</pre></details>${state.refactor.sections.map(s => `<details><summary>Preview ${esc(s.title)}</summary><pre class="plan-outline">${esc(s.content)}</pre></details>`).join('')}<div class="row"><button class="btn danger" id="plan-refactor-apply" ${state.busy ? 'disabled' : ''}>${refactorArmed ? 'Confirm: write the split files' : 'Apply this split'}</button><span class="badge">${refactorArmed ? 'Writes the reviewed section files, backs up the original, and turns the document into the linked index.' : 'Writing happens only after this review and a fresh re-check against the current document.'}</span></div></div>` : ''}</section></div>`;
    const drop = pane.querySelector('#plan-drop'), file = pane.querySelector('#plan-file'), text = pane.querySelector('#plan-text');
    text.oninput = e => { state.plan = e.target.value; state.filename = ''; state.result = null; state.answers = {}; state.decisions = []; state.accepted = {}; state.applied = {}; state.error = ''; state.message = ''; requestNumber++; pane.querySelector('#plan-result-questions')?.remove(); pane.querySelector('#plan-result-edits')?.remove(); pane.querySelectorAll('[role="alert"],[role="status"]').forEach(el => el.remove()); };
    file.onchange = () => { if (!state.busy) loadFile(file.files[0], pane); };
    drop.addEventListener('dragover', e => { e.preventDefault(); if (!state.busy) drop.classList.add('over'); });
    drop.addEventListener('dragleave', () => drop.classList.remove('over'));
    drop.addEventListener('drop', e => { e.preventDefault(); drop.classList.remove('over'); if (!state.busy) loadFile(e.dataTransfer.files[0], pane); });
    drop.addEventListener('keydown', e => { if ((e.key === 'Enter' || e.key === ' ') && e.target === drop && !state.busy) { e.preventDefault(); file.click(); } });
    pane.querySelector('#plan-analyze').onclick = () => analyze(pane,false);
    pane.querySelector('#plan-refine')?.addEventListener('click', () => analyze(pane,true));
    pane.querySelector('#plan-export')?.addEventListener('click', exportProposal);
    pane.querySelector('#plan-refactor-doc')?.addEventListener('change', e => { state.refactorPath = e.target.value; state.refactor = null; refactorArmed = false; draw(pane); });
    pane.querySelector('#plan-refactor')?.addEventListener('click', () => proposeRefactor(pane));
    pane.querySelector('#plan-refactor-apply')?.addEventListener('click', () => { if (!refactorArmed) { refactorArmed = true; draw(pane); return; } applyRefactor(pane); });
    pane.querySelectorAll('[data-answer-index]').forEach(el => el.oninput = () => { const q = qs[Number(el.dataset.answerIndex)]; state.answers[q.id] = el.value; });
    pane.querySelectorAll('[data-approve]').forEach(el => el.onchange = () => { const i = Number(el.dataset.approve); state.accepted[i] = el.checked; pane.querySelector(`[data-apply="${i}"]`).disabled = !el.checked; });
    pane.querySelectorAll('[data-apply]').forEach(el => el.onclick = () => apply(pane, Number(el.dataset.apply)));
    pane.querySelectorAll('[data-source]').forEach(el => el.onclick = () => { if (typeof window.openDoc === 'function') window.openDoc('canon:' + el.dataset.source); });
  }
  window.renderPlanReview = pane => draw(pane);
})();
