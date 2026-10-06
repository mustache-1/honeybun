// Only connect reviewed, final native captures. Empty entries remain visibly labeled placeholders.
(function () {
  const landing = document.querySelector('#scr-landing');
  if (!landing) return;
  const screenshots = { home: '', insight: '', plan: '', debt: '', goals: '', together: '', inbox: '' };
  const descriptions = {
    home: 'Honeybun native Home showing Safe to Spend and upcoming bills',
    insight: 'Final Phase 7 From Bun observations and customer explanations',
    plan: 'Honeybun native Plan showing monthly budgets, bills and forecast',
    debt: 'Honeybun native Debt Center+ showing estimated payoff comparison',
    goals: 'Honeybun native Goals showing contributions and progress',
    together: 'Honeybun native Together showing shared planning',
    inbox: 'Honeybun native Bun Inbox with current notifications and streak card'
  };
  landing.querySelectorAll('[data-native-shot]').forEach((frame) => {
    const key = frame.dataset.nativeShot, src = screenshots[key];
    if (!src) return;
    const image = new Image();
    image.alt = descriptions[key]; image.width = 1206; image.height = 2622;
    image.loading = 'lazy'; image.decoding = 'async'; image.className = 'hbl-native-capture';
    image.onload = () => {
      frame.querySelector('.hbl-capture-slot')?.remove();
      frame.classList.add('has-capture');
      frame.querySelector('figcaption').textContent = 'REAL FINAL NATIVE SCREENSHOT';
    };
    image.onerror = () => image.remove(); // Keep the labeled placeholder if a capture is unavailable.
    frame.querySelector('.hbl-screen').append(image);
    image.src = src;
  });
  const reduce = matchMedia('(prefers-reduced-motion: reduce)');
  if (!reduce.matches) {
    const field = document.createElement('div'); field.className = 'hbl-firefly-field'; field.setAttribute('aria-hidden', 'true');
    const count = matchMedia('(max-width: 800px)').matches ? 14 : 28;
    for (let i = 0; i < count; i++) {
      const particle = document.createElement('i');
      particle.className = i % 7 === 0 ? 'hbl-particle-leaf' : 'hbl-particle-firefly';
      particle.style.cssText = `--x:${3 + (i * 37) % 94}%;--y:${2 + (i * 23) % 96}%;--size:${2 + i % 2}px;--duration:${12 + i % 7}s;--delay:-${i * 1.7}s`;
      if (i % 7 === 0) particle.innerHTML = '<svg viewBox="0 0 24 24"><path d="m12 1 2 6 5-3-1 6 5 1-5 4 1 4-6-2v6h-2v-6l-6 2 1-4-5-4 5-1-1-6 5 3Z" fill="currentColor"/></svg>';
      field.append(particle);
    }
    landing.querySelector('.hbl-page').append(field);
    reduce.addEventListener('change', (event) => { if (event.matches) field.remove(); });
  }
  const views = [...landing.querySelectorAll('.hbl-subpage')];
  const links = [...landing.querySelectorAll('[data-hbl-view]')];
  function clearViews() { views.forEach((view) => { view.hidden = true; }); links.forEach((link) => link.removeAttribute('aria-current')); landing.querySelector('#lpUpdatesLink').removeAttribute('aria-current'); }
  function showLanding() {
    clearViews(); landing.querySelector('#lp-updates').hidden = true; landing.querySelector('#lp-rewards').hidden = true; landing.removeAttribute('data-view');
  }
  links.forEach((link) => link.addEventListener('click', (event) => {
    event.preventDefault(); showLanding();
    const view = link.dataset.hblView, section = landing.querySelector('#lp-' + view);
    section.hidden = false; landing.dataset.view = view;
    links.filter((entry) => entry.dataset.hblView === view).forEach((entry) => entry.setAttribute('aria-current', 'page'));
    window.scrollTo({ top: 0, behavior: 'auto' }); section.querySelector('h1').focus({ preventScroll: true });
  }));
  landing.querySelectorAll('[data-hbl-back]').forEach((button) => button.addEventListener('click', () => { showLanding(); window.scrollTo({ top: 0, behavior: 'auto' }); landing.querySelector('.hbl-brand').focus({ preventScroll: true }); }));
  landing.querySelectorAll('#lpUpdatesLink,[data-updates-go]').forEach((link) => link.addEventListener('click', () => { clearViews(); landing.querySelector('#lpUpdatesLink').setAttribute('aria-current', 'page'); }));
  landing.querySelector('#lpUpdBack').addEventListener('click', clearViews);
  landing.querySelectorAll('.hbl-brand,.hbl-footer-brand').forEach((link) => link.addEventListener('click', (event) => { event.preventDefault(); showLanding(); window.scrollTo({ top: 0, behavior: reduce.matches ? 'auto' : 'smooth' }); }));
  landing.querySelectorAll('a[href^="#lp-"]:not([data-hbl-view]):not(#lpUpdatesLink):not([data-updates-go])').forEach((link) => {
    link.onclick = (event) => { event.preventDefault(); showLanding(); document.querySelector(link.getAttribute('href'))?.scrollIntoView({ behavior: reduce.matches ? 'auto' : 'smooth' }); };
  });
  landing.querySelectorAll('.hbl-faq-list summary').forEach((summary) => summary.addEventListener('click', (event) => { event.preventDefault(); summary.parentElement.open = !summary.parentElement.open; }));
  const tabs = [...landing.querySelectorAll('[data-shot-tab]')];
  function selectShot(tab) {
    tabs.forEach((item) => {
      const active = item === tab;
      item.setAttribute('aria-selected', String(active)); item.tabIndex = active ? 0 : -1;
      landing.querySelector('#hbl-panel-' + item.dataset.shotTab).hidden = !active;
    });
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => selectShot(tab));
    tab.addEventListener('keydown', (event) => {
      if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
      event.preventDefault(); const next = event.key === 'Home' ? 0 : event.key === 'End' ? tabs.length - 1 : (index + (event.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
      selectShot(tabs[next]); tabs[next].focus();
    });
  });
})();
