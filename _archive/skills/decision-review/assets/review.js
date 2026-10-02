'use strict';
const el = id => document.getElementById(id);
const REVIEW = JSON.parse(el('review-data').textContent);
const DATA = REVIEW.items;
const byId = new Map(DATA.map(item => [item.id, item]));
const GROUPS = [...new Set(DATA.map(item => item.group))];
const SPECIAL = [
  {id: 'custom', title: 'Use a different approach', detail: 'Describe your preferred approach in the comment.'},
  {id: 'discuss', title: 'Needs discussion', detail: 'Record the question or missing information below.'},
  {id: 'defer', title: 'Defer this item', detail: 'Record when to revisit it and what can proceed meanwhile.'},
  {id: 'disagree', title: 'Disagree with the premise', detail: 'Explain which assumption or conclusion is incorrect.'}
];
const overallLabels = {
  '': 'No overall decision', revise: 'Revise using my decisions',
  investigate: 'Investigate the open questions first', ready: 'Ready for the next step', hold: 'Hold for now'
};
const allOptions = item => [...item.options, ...SPECIAL];
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
})[c]);
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const storageKey = 'decision-review:1:' + REVIEW.reviewId + ':' + REVIEW.contentHash;
let state = {
  schemaVersion: 1, reviewId: REVIEW.reviewId, contentHash: REVIEW.contentHash,
  updatedAt: null, answers: {}, overall: '', overallComment: '',
  ui: {current: DATA[0].id, summary: false, search: '', group: 'all', status: 'all', expanded: {}}
};
let storageAvailable = true;
let blockedStorage = false;
let recoveryNotice = '';
let persistedValue = null;

function validate(raw) {
  if (!object(raw) || raw.schemaVersion !== 1 || raw.reviewId !== REVIEW.reviewId) {
    throw Error('This is not a feedback backup for this review.');
  }
  if (raw.contentHash !== REVIEW.contentHash) {
    throw Error('The questions or proposals changed. Open the matching review to use this backup; decisions were not replaced.');
  }
  if (!object(raw.answers)) throw Error('Invalid answers.');
  const answers = {};
  for (const [id, a] of Object.entries(raw.answers)) {
    if (!byId.has(id) || !object(a) || typeof a.choice !== 'string' || typeof a.comment !== 'string' ||
        (a.choice && !allOptions(byId.get(id)).some(o => o.id === a.choice))) throw Error('Invalid decision or comment.');
    answers[id] = {choice: a.choice, comment: a.comment};
  }
  if (!Object.hasOwn(overallLabels, raw.overall) || typeof raw.overallComment !== 'string') {
    throw Error('Invalid overall feedback.');
  }
  if (raw.updatedAt !== null && (typeof raw.updatedAt !== 'string' || !Number.isFinite(Date.parse(raw.updatedAt)))) {
    throw Error('Invalid backup timestamp.');
  }
  const u = raw.ui;
  if (!object(u) || !byId.has(u.current) || typeof u.summary !== 'boolean' || typeof u.search !== 'string' ||
      !['all', ...GROUPS].includes(u.group) || !['all', 'pending', 'selected', 'flagged'].includes(u.status) ||
      !object(u.expanded) || Object.values(u.expanded).some(v => typeof v !== 'boolean')) {
    throw Error('Invalid saved view.');
  }
  return {schemaVersion: 1, reviewId: REVIEW.reviewId, contentHash: REVIEW.contentHash,
    updatedAt: raw.updatedAt, answers, overall: raw.overall, overallComment: raw.overallComment,
    ui: {current: u.current, summary: u.summary, search: u.search, group: u.group, status: u.status, expanded: {...u.expanded}}};
}
try {
  persistedValue = localStorage.getItem(storageKey);
  if (persistedValue) state = validate(JSON.parse(persistedValue));
} catch (error) {
  storageAvailable = false;
  blockedStorage = Boolean(persistedValue);
  recoveryNotice = 'Saved feedback could not be loaded. Existing browser data is preserved. Export your work before recovery.';
}

function answer(id) { return state.answers[id] || {choice: '', comment: ''}; }
function status(item) {
  const a = answer(item.id);
  if (!a.choice) return 'pending';
  if (['discuss', 'defer', 'disagree'].includes(a.choice) ||
      ((a.choice === 'custom' || item.options.find(o => o.id === a.choice)?.requiresComment) && !a.comment.trim())) {
    return 'flagged';
  }
  return 'selected';
}
function selectedLabel(item) { return allOptions(item).find(o => o.id === answer(item.id).choice)?.title || 'No decision'; }
function counts() {
  return {reviewed: DATA.filter(i => answer(i.id).choice).length,
    selected: DATA.filter(i => status(i) === 'selected').length,
    flagged: DATA.filter(i => status(i) === 'flagged').length,
    pending: DATA.filter(i => status(i) === 'pending').length};
}
function notify(message) {
  el('toast').textContent = message;
  el('toast').hidden = false;
  clearTimeout(notify.timer);
  notify.timer = setTimeout(() => { el('toast').hidden = true; }, 6000);
}
function updateSaveStatus() {
  el('save-status').textContent = blockedStorage
    ? 'Autosave paused to preserve conflicting or invalid saved data. Back up this tab, then reload.'
    : storageAvailable
      ? state.updatedAt ? 'Saved in this browser · ' + new Date(state.updatedAt).toLocaleTimeString()
        : 'Changes save automatically in this browser.'
      : 'Browser autosave unavailable. Use Backup JSON before closing this page.';
}
function save() {
  state.updatedAt = new Date().toISOString();
  if (!blockedStorage) {
    try {
      // A second open copy must not silently replace newer feedback from another tab.
      if (localStorage.getItem(storageKey) !== persistedValue) {
        blockedStorage = true;
        notify('Another tab changed this review. Back up this tab before reloading to read those changes.');
      } else {
        const nextValue = JSON.stringify(state);
        localStorage.setItem(storageKey, nextValue);
        persistedValue = nextValue;
        storageAvailable = true;
      }
    } catch (error) { storageAvailable = false; }
  }
  updateSaveStatus();
}
function matches(item) {
  const q = state.ui.search.trim().toLowerCase();
  return (state.ui.group === 'all' || item.group === state.ui.group) &&
    (state.ui.status === 'all' || status(item) === state.ui.status) &&
    (!q || JSON.stringify(item).toLowerCase().includes(q) || answer(item.id).comment.toLowerCase().includes(q));
}
function renderNav() {
  const c = counts();
  el('progress-text').textContent = c.reviewed + ' of ' + DATA.length + ' reviewed';
  el('flag-count').textContent = c.flagged ? c.flagged + ' follow-up' : '';
  el('progress').max = DATA.length;
  el('progress').value = c.reviewed;
  const filtered = DATA.filter(matches);
  el('nav').innerHTML = filtered.length ? GROUPS.map(group => {
    const rows = filtered.filter(i => i.group === group);
    return rows.length ? '<div class="navgroup">' + esc(group) + ' · ' + rows.length + '</div>' + rows.map(item =>
      '<button class="navitem" data-id="' + item.id + '" aria-current="' + (!state.ui.summary && state.ui.current === item.id) +
      '"><span class="navid">' + item.id + '</span><span class="navtitle">' + esc(item.title) +
      '</span><span class="dot ' + (status(item) === 'selected' ? 'done' : status(item) === 'flagged' ? 'flagged' : '') +
      '" aria-label="' + status(item) + '"></span></button>').join('') : '';
  }).join('') : '<p class="empty">No matching items. Try another filter.</p>';
}
function list(values, ordered = false) {
  const tag = ordered ? 'ol' : 'ul';
  return '<' + tag + '>' + values.map(t => '<li>' + esc(t) + '</li>').join('') + '</' + tag + '>';
}
function details(key, label, body, className) {
  return '<details class="' + className + '" data-detail="' + esc(key) + '"' +
    (state.ui.expanded[key] ? ' open' : '') + '><summary>' + esc(label) + '</summary>' + body + '</details>';
}
function optionHtml(item, option) {
  const label = '<label class="option"><input type="radio" name="decision" value="' + option.id + '" ' +
    (answer(item.id).choice === option.id ? 'checked' : '') + '><span><strong>' + esc(option.title) + '</strong> ' +
    (option.recommended ? '<span class="rec-tag">Recommended</span>' : '') + '<small>' + esc(option.detail) + '</small>' +
    (option.cost ? '<span class="tradeoff"><b>What you accept:</b> ' + esc(option.cost) + '</span>' : '') + '</span></label>';
  const p = option.proposal;
  if (!p) return label;
  const fields = p.data.length ? '<h4>Proposed data or configuration</h4><table><thead><tr><th>Location / field</th>' +
    '<th>Type</th><th>Purpose</th></tr></thead><tbody>' + p.data.map(d => '<tr><td data-label="Location">' + esc(d.place) +
      '</td><td data-label="Type">' + esc(d.type) + '</td><td data-label="Purpose">' + esc(d.purpose) + '</td></tr>').join('') + '</tbody></table>' : '';
  return '<div class="proposal">' + label + details(item.id + ':proposal:' + option.id, 'Read the concrete proposal',
    fields + '<h4>What happens, step by step</h4>' + list(p.steps, true) + '<h4>If something goes wrong</h4><p>' + esc(p.failure) +
    '</p>' + (p.example ? '<h4>Example with this option</h4><p class="example-in-option">' + esc(p.example) + '</p>' : '') +
    '<h4>What this choice covers</h4><p class="scope">' + esc(p.scope) + '</p>', 'proposal-details') + '</div>';
}
function evidenceHtml(item) {
  return '<ul>' + item.evidence.map(e => '<li>' + (e.url
    ? '<a href="' + esc(e.url) + '" target="_blank" rel="noopener noreferrer">' + esc(e.note) + '</a>'
    : '<strong>' + esc(e.note) + '</strong><br><code>' + esc(e.path) + (e.lines ? ':' + esc(e.lines) : '') + '</code>') + '</li>').join('') + '</ul>';
}
function mediaHtml(item) {
  return item.media.map(m => '<figure class="media">' + (m.kind === 'recording'
    ? '<video controls preload="metadata" aria-label="' + esc(m.alt) + '" src="' + esc(m.src) + '"></video>'
    : '<a href="' + esc(m.src) + '" target="_blank" rel="noopener"><img src="' + esc(m.src) + '" alt="' + esc(m.alt) + '"></a>') +
    '<figcaption><strong>' + (m.kind === 'diagram' ? 'Explanation' : 'Captured evidence') + ':</strong> ' + esc(m.caption) +
    (m.source ? ' <a href="' + esc(m.source) + '">Mermaid source</a>' : '') + '</figcaption></figure>').join('');
}
function showItem(id, scroll = true) {
  state.ui.current = id;
  state.ui.summary = false;
  save(); render();
  if (scroll) el('main').scrollIntoView({block: 'start'});
}
function bindDetails() {
  el('content').querySelectorAll('details[data-detail]').forEach(d => {
    const key = d.dataset.detail;
    // Persist the user's click before navigation can cancel the deferred toggle event.
    d.querySelector('summary').addEventListener('click', () => {
      state.ui.expanded[key] = !d.open; save();
    });
    d.addEventListener('toggle', () => {
      if (Boolean(state.ui.expanded[key]) !== d.open) { state.ui.expanded[key] = d.open; save(); }
    });
  });
}
function refreshItemStatus() {
  const item = byId.get(state.ui.current);
  el('choice-summary').textContent = selectedLabel(item);
  el('item-status').textContent = status(item) === 'pending' ? 'Awaiting your decision'
    : status(item) === 'flagged' ? 'Follow-up needed' : 'Approach chosen';
}
function renderItem() {
  const item = byId.get(state.ui.current), a = answer(item.id), index = DATA.indexOf(item);
  el('position').textContent = 'Item ' + (index + 1) + ' of ' + DATA.length;
  el('summary-button').textContent = 'Decision summary';
  el('content').innerHTML = '<article class="sheet" aria-labelledby="item-title"><div class="meta"><span class="itemid">' +
    item.id + '</span><span class="badge">' + esc(item.group) + '</span><span class="badge" id="item-status"></span></div>' +
    '<h2 id="item-title">' + esc(item.title) + '</h2><div class="decision-box"><strong>Decision you are making</strong><p>' +
    esc(item.decision) + '</p></div><p>' + esc(item.problem) + '</p>' +
    (item.definitions.length ? '<div class="definitions">' + list(item.definitions) + '</div>' : '') +
    '<div class="example"><span class="label">What this means in practice</span><p>' + esc(item.scenario) + '</p></div>' +
    mediaHtml(item) + '<div class="recommendation"><span class="label">Recommendation</span><p>' + esc(item.recommendation) +
    '</p></div><fieldset><legend>' + esc(item.question) + '</legend><div class="options">' +
    item.options.map(o => optionHtml(item, o)).join('') + '</div>' +
    details(item.id + ':alternate', 'Different approach, discussion, deferral, or disagreement',
      '<div class="options">' + SPECIAL.map(o => optionHtml(item, o)).join('') + '</div>', 'alternate') +
    '</fieldset><label class="field-label" for="comment">Your comment or decision details</label><textarea id="comment" ' +
    'placeholder="Add your preferred behavior, constraint, or question.">' + esc(a.comment) + '</textarea>' +
    '<div class="hint">Changing a choice keeps your comment. A custom approach needs a comment.</div>' +
    '<div class="decision-foot"><span id="choice-summary"></span><button id="clear-choice">Clear choice</button></div>' +
    '<h3>How to verify the result</h3><div class="checks">' + list(item.checks) + '</div>' +
    details(item.id + ':evidence', 'Evidence and source references (' + item.evidence.length + ')',
      '<p class="hint">Source paths describe the reviewed revision. Line numbers can change.</p>' + evidenceHtml(item), 'evidence') +
    (item.related.length ? '<div class="related">Related decisions ' + item.related.map(id => '<button data-related="' + id + '">' +
      id + ' · ' + esc(byId.get(id).title) + '</button>').join('') + '</div>' : '') + '</article>' +
    '<div class="bottom-nav"><button id="previous" ' + (index === 0 ? 'disabled' : '') + '>← Previous</button>' +
    '<button id="next" ' + (index === DATA.length - 1 ? 'disabled' : '') + '>Next item →</button></div>';
  el('content').querySelectorAll('input[name=decision]').forEach(r => r.addEventListener('change', () => {
    state.answers[item.id] = {...answer(item.id), choice: r.value}; save(); renderNav(); refreshItemStatus();
  }));
  el('comment').oninput = e => { state.answers[item.id] = {...answer(item.id), comment: e.target.value}; save(); renderNav(); refreshItemStatus(); };
  el('clear-choice').onclick = () => { state.answers[item.id] = {...answer(item.id), choice: ''}; save(); render(); };
  el('previous').onclick = () => showItem(DATA[index - 1].id);
  el('next').onclick = () => showItem(DATA[index + 1].id);
  el('content').querySelectorAll('[data-related]').forEach(b => { b.onclick = () => showItem(b.dataset.related); });
  refreshItemStatus(); bindDetails();
}
function renderSummary() {
  const c = counts();
  el('position').textContent = 'All decisions · ' + DATA.length + ' items';
  el('summary-button').textContent = 'Back to item';
  el('content').innerHTML = '<section class="sheet"><div class="eyebrow">Your review</div><h2>Decision summary</h2>' +
    '<p class="muted">Selections record your feedback. They do not execute changes or authorize implementation automatically.</p>' +
    '<div class="summary-metrics">' + [[c.selected, 'Approaches chosen'], [c.flagged, 'Need follow-up'], [c.pending, 'No decision yet']].map(
      ([n, label]) => '<div><strong>' + n + '</strong><span>' + label + '</span></div>').join('') + '</div>' +
    '<label class="field-label" for="overall">Overall direction</label><select id="overall" class="overall-select">' +
    Object.entries(overallLabels).map(([v, t]) => '<option value="' + v + '" ' + (state.overall === v ? 'selected' : '') + '>' + t + '</option>').join('') +
    '</select><label class="field-label" for="overall-comment">General feedback and priorities</label>' +
    '<textarea id="overall-comment">' + esc(state.overallComment) + '</textarea><p id="readiness-note" class="hint"></p>' +
    '<h3>All items</h3>' + DATA.map(item => {
      const a = answer(item.id), option = item.options.find(o => o.id === a.choice);
      return '<div class="summary-row"><div class="summary-row-head"><h3>' + item.id + ' · ' + esc(item.title) +
        '</h3><button data-open="' + item.id + '">Review</button></div><p class="' + (status(item) !== 'selected' ? 'unresolved' : '') +
        '"><strong>' + esc(selectedLabel(item)) + '</strong> · ' + status(item) + '</p>' +
        (option ? '<p>' + esc(option.detail) + '</p><p class="chosen-cost">Tradeoff: ' + esc(option.cost) + '</p>' : '') +
        (a.comment ? '<p>' + esc(a.comment) + '</p>' : '') + '</div>';
    }).join('') + '</section>';
  function readiness() {
    el('readiness-note').textContent = state.overall === 'ready' && (c.pending || c.flagged)
      ? (c.pending + c.flagged) + ' items remain open or need follow-up. Their status is preserved in exports.'
      : 'Export feedback for Markdown, or use Backup JSON to resume elsewhere.';
  }
  el('overall').onchange = e => { state.overall = e.target.value; save(); readiness(); };
  el('overall-comment').oninput = e => { state.overallComment = e.target.value; save(); };
  el('content').querySelectorAll('[data-open]').forEach(b => { b.onclick = () => showItem(b.dataset.open); });
  readiness();
}
function render() {
  el('search').value = state.ui.search;
  el('group-filter').value = state.ui.group;
  el('status-filter').value = state.ui.status;
  renderNav();
  if (state.ui.summary) renderSummary(); else renderItem();
}
function download(name, body, type) {
  const url = URL.createObjectURL(new Blob([body], {type}));
  const a = document.createElement('a');
  a.href = url; a.download = name;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 30000);
}
function markdown() {
  const c = counts();
  const lines = ['# ' + REVIEW.title + ' — feedback', '', 'Review: ' + REVIEW.reviewId,
    'Content revision: ' + REVIEW.contentHash, 'Exported: ' + new Date().toISOString(), '',
    '## Overall direction', '', overallLabels[state.overall], '', state.overallComment, '',
    c.selected + ' chosen; ' + c.flagged + ' need follow-up; ' + c.pending + ' undecided.', '',
    'Selections are feedback, not automatic implementation authorization.', ''];
  for (const item of DATA) {
    const a = answer(item.id), o = allOptions(item).find(option => option.id === a.choice);
    lines.push('## ' + item.id + ' — ' + item.title, '', '- Status: ' + status(item), '- Decision: ' + selectedLabel(item), '',
      '**What this means in practice:** ' + item.scenario, '', '**Comment:**', a.comment || '(No comment)', '');
    if (o) {
      lines.push('**Selected option:** ' + o.detail, '');
      if (o.cost) lines.push('Tradeoff: ' + o.cost, '');
      if (o.proposal) {
        const p = o.proposal;
        lines.push('**Selected proposal:**', ...p.steps.map((s, i) => (i + 1) + '. ' + s), '',
          'Failure behavior: ' + p.failure, '', 'Scope: ' + p.scope, '',
          ...p.data.map(d => '- ' + d.place + ' (' + d.type + '): ' + d.purpose), '');
      }
    }
    lines.push('**How to verify:**', ...item.checks.map(t => '- ' + t), '', '**Evidence:**',
      ...item.evidence.map(e => '- ' + e.note + ': ' + (e.url || e.path + (e.lines ? ':' + e.lines : ''))),
      ...item.media.map(m => '- ' + m.caption + ': ' + m.src), '',
      ...(item.related.length ? ['Related decisions: ' + item.related.join(', '), ''] : []));
  }
  return lines.join('\n');
}
el('title').textContent = REVIEW.title;
el('subtitle').textContent = REVIEW.subtitle;
el('intro').textContent = REVIEW.intro;
el('notice').textContent = REVIEW.notice;
el('group-filter').innerHTML = '<option value="all">All categories</option>' + GROUPS.map(g => '<option>' + esc(g) + '</option>').join('');
el('nav').onclick = e => { const b = e.target.closest('[data-id]'); if (b) showItem(b.dataset.id); };
for (const [id, key] of [['search', 'search'], ['group-filter', 'group'], ['status-filter', 'status']]) {
  el(id).addEventListener(id === 'search' ? 'input' : 'change', e => { state.ui[key] = e.target.value; save(); renderNav(); });
}
el('summary-button').onclick = () => { state.ui.summary = !state.ui.summary; save(); render(); el('main').scrollIntoView({block: 'start'}); };
el('next-pending').onclick = () => {
  const index = DATA.findIndex(i => i.id === state.ui.current);
  const next = [...DATA.slice(index + 1), ...DATA.slice(0, index + 1)].find(i => status(i) === 'pending');
  if (next) showItem(next.id); else notify('Every item has a decision. Check the summary for follow-ups.');
};
el('export-json').onclick = () => download(REVIEW.reviewId + '-feedback.json', JSON.stringify({
  ...state, exportedAt: new Date().toISOString(),
  selections: DATA.map(i => ({id: i.id, title: i.title, decision: selectedLabel(i), status: status(i),
    selectedProposal: i.options.find(o => o.id === answer(i.id).choice) || null}))
}, null, 2), 'application/json');
el('export-md').onclick = () => download(REVIEW.reviewId + '-feedback.md', markdown(), 'text/markdown;charset=utf-8');
el('import-btn').onclick = () => el('import-file').click();
el('import-file').onchange = async event => {
  const file = event.target.files[0];
  if (!file) return;
  try {
    const incoming = validate(JSON.parse(await file.text()));
    if ((Object.values(state.answers).some(a => a.choice || a.comment) || state.overall || state.overallComment) &&
        !confirm('Replace this tab’s decisions and comments with the backup? Export first to keep both.')) return;
    state = incoming; save(); render(); notify('Imported decisions, comments, and saved view.');
  } catch (error) { notify('Import failed: ' + error.message); }
  finally { event.target.value = ''; }
};
window.addEventListener('storage', event => {
  if (event.key === storageKey && event.newValue !== persistedValue) {
    blockedStorage = true; updateSaveStatus();
    notify('Another tab changed this review. Back up this tab before reloading.');
  }
});
render(); updateSaveStatus();
if (recoveryNotice) notify(recoveryNotice);
