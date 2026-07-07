// Path prefix from the page's depth relative to the dashboard root.
// Overview (index.html) is depth 0; category pages under pages/ are depth 1.
function rootPrefix() {
  const depth = parseInt(document.body.dataset.depth || '0', 10);
  return '../'.repeat(depth);
}

function buildNav(activePage) {
  const nav = document.getElementById('main-nav');
  const prefix = rootPrefix();
  const links = [
    { href: 'index.html', label: 'Overview', id: 'index' },
    ...CATEGORIES.map(c => ({ href: `pages/${c.id}.html`, label: c.name, id: c.id }))
  ];

  nav.innerHTML = `
    <div class="nav-inner">
      <a href="${prefix}index.html" class="nav-brand">AI CY8ER CMD</a>
      <ul class="nav-links">
        ${links.map(l => `
          <li><a href="${prefix}${l.href}" class="${l.id === activePage ? 'active' : ''}">${l.label}</a></li>
        `).join('')}
      </ul>
    </div>`;
}

function buildFooter() {
  document.getElementById('main-footer').innerHTML =
    `AI Cy8er Command Center &mdash; EotW CTF SS CASE IT 2025`;
}

function renderOverview() {
  const stats = getStats();
  const solveRate = stats.total > 0 ? Math.round((stats.solved / stats.total) * 100) : 0;

  document.getElementById('app').innerHTML = `
    <div class="hero">
      <h1>AI Cy8er Command Center</h1>
      <div class="subtitle">EotW CTF &bull; SS CASE IT 2025</div>
    </div>

    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-value">${stats.total}</div>
        <div class="stat-label">Challenges</div>
      </div>
      <div class="stat-card green">
        <div class="stat-value">${stats.solved}</div>
        <div class="stat-label">Solved</div>
      </div>
      <div class="stat-card magenta">
        <div class="stat-value">${stats.points}</div>
        <div class="stat-label">Points</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${solveRate}%</div>
        <div class="stat-label">Solve Rate</div>
      </div>
    </div>

    <div class="section-title">Categories</div>
    <div class="category-grid">
      ${CATEGORIES.map(cat => {
        const s = stats.byCategory[cat.id];
        const pct = s.total > 0 ? Math.round((s.solved / s.total) * 100) : 0;
        return `
          <a href="pages/${cat.id}.html" class="category-card">
            <div class="card-icon">${cat.icon}</div>
            <div class="card-title">${cat.name}</div>
            <div class="card-stats">${s.solved}/${s.total} solved &bull; ${s.points} pts</div>
            <div class="card-bar"><div class="card-bar-fill" style="width:${pct}%"></div></div>
          </a>`;
      }).join('')}
    </div>`;
}

function renderCategoryPage(catId) {
  const cat = CATEGORIES.find(c => c.id === catId);
  if (!cat) return;

  const prefix = rootPrefix();
  const challenges = getChallengesByCategory(catId);
  const app = document.getElementById('app');
  const diffClass = d => `badge badge-${d.toLowerCase()}`;

  if (challenges.length === 0) {
    app.innerHTML = `
      <div class="page-header">
        <div class="page-icon">${cat.icon}</div>
        <div>
          <h1>${cat.name}</h1>
          <p>0 challenges</p>
        </div>
      </div>
      <div class="empty-state">
        <div class="empty-icon">${cat.icon}</div>
        <p>No challenges recorded yet.</p>
      </div>`;
    return;
  }

  const solved = challenges.filter(c => c.solved).length;
  const points = challenges.filter(c => c.solved).reduce((s, c) => s + c.points, 0);

  app.innerHTML = `
    <div class="page-header">
      <div class="page-icon">${cat.icon}</div>
      <div>
        <h1>${cat.name}</h1>
        <p>${solved}/${challenges.length} solved &bull; ${points} pts</p>
      </div>
    </div>
    <table class="challenge-table">
      <thead>
        <tr>
          <th>Status</th>
          <th>Challenge</th>
          <th>Points</th>
          <th>Difficulty</th>
          <th>Writeup</th>
        </tr>
      </thead>
      <tbody>
        ${challenges.map(ch => `
          <tr>
            <td><span class="badge ${ch.solved ? 'badge-solved' : 'badge-unsolved'}">${ch.solved ? 'Solved' : 'Unsolved'}</span></td>
            <td>
              <strong>${ch.title}</strong>
              ${ch.summary ? `<br><span style="color:var(--text-muted);font-size:0.8rem">${ch.summary}</span>` : ''}
            </td>
            <td><span class="points">${ch.points}</span></td>
            <td><span class="${diffClass(ch.difficulty)}">${ch.difficulty}</span></td>
            <td>${ch.writeup ? `<a href="${prefix}${ch.writeup}" class="writeup-link">[View]</a>` : '<span style="color:var(--text-muted)">--</span>'}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>`;
}

// Single entry point: each page sets <body data-page="..."> and calls initDashboard().
function initDashboard() {
  const page = document.body.dataset.page;
  buildNav(page === 'index' ? 'index' : page);
  buildFooter();
  if (page === 'index') {
    renderOverview();
  } else {
    renderCategoryPage(page);
  }
}
