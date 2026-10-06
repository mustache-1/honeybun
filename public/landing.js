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
      frame.querySelector('.hbl-product-art')?.remove();
      frame.classList.add('has-capture');
    };
    image.onerror = () => image.remove(); // Keep the labeled placeholder if a capture is unavailable.
    frame.querySelector('.hbl-screen').append(image);
    image.src = src;
  });
  const reduce = matchMedia('(prefers-reduced-motion: reduce)');
  // Content-sized mobile art offset, not viewport/page scaling. The shared world remains one layer.
  if ('ResizeObserver' in window) {
    let queued = false;
    const placeWorld = () => {
      queued = false;
      if (!matchMedia('(max-width:959px)').matches) { landing.style.removeProperty('--hbl-world-start'); return; }
      const intro = landing.querySelector('.hbl-intro'), hero = landing.querySelector('.hbl-hero');
      const top = intro.getBoundingClientRect().bottom - hero.getBoundingClientRect().top + 24;
      landing.style.setProperty('--hbl-world-start', `${Math.ceil(top)}px`);
    };
    const layoutObserver = new ResizeObserver(() => { if (!queued) { queued = true; requestAnimationFrame(placeWorld); } });
    layoutObserver.observe(landing.querySelector('.hbl-intro'));
  }
  const mobile = matchMedia('(max-width: 640px)');
  // Small, staggered fireflies throughout each scene; no full-page repaint loop.
  function atmosphere() {
    landing.querySelectorAll('.hbl-firefly-field').forEach((field) => field.remove());
    // Reduced motion keeps stationary lights visible; CSS disables their drift.
    const regions = [...landing.querySelectorAll('.hbl-hero,.hbl-safe,.hbl-insights,.hbl-features,.hbl-together,.hbl-trust,.hbl-faq,.hbl-final')];
    regions.forEach((region, ri) => {
      const field = document.createElement('div'); field.className = 'hbl-firefly-field'; field.setAttribute('aria-hidden', 'true');
      const count = region.classList.contains('hbl-hero') ? (mobile.matches ? 12 : 24) : (mobile.matches ? 6 : 12);
      for (let i = 0; i < count; i++) {
        const n = ri * 24 + i, particle = document.createElement('i');
        const x = 4 + (i * 37 + ri * 19) % 92;
        particle.style.cssText = `--x:${x}%;--y:${12 + (n * 23) % 76}%;--size:${2.5 + n % 3}px;--duration:${7 + n % 7}s;--delay:-${1 + n * 1.3}s;--sway:${n % 2 ? 30 : -30}px`;
        field.append(particle);
      }
      region.append(field);
    });
  }
  atmosphere(); reduce.addEventListener('change', atmosphere); mobile.addEventListener('change', atmosphere);
  document.addEventListener('visibilitychange', () => landing.classList.toggle('hbl-paused', document.hidden));
  // The old hb/rv reveal timing, adapted to the new product cards and headings.
  if ('IntersectionObserver' in window && !reduce.matches) {
    landing.classList.add('hbl-reveals');
    const observer = new IntersectionObserver((entries) => entries.forEach((entry) => {
      if (entry.isIntersecting) { entry.target.classList.add('in'); observer.unobserve(entry.target); }
    }), { rootMargin: '0px 0px -6% 0px', threshold: .06 });
    landing.querySelectorAll('.hbl-card,.hbl-section-intro,.hbl-safe-copy,.hbl-insight-copy,.hbl-together-copy').forEach((node) => { node.classList.add('hbl-reveal'); observer.observe(node); });
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
