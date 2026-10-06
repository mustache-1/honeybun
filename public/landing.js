// Public single-scene homepage; native app and backend remain independent.
(function () {
  const landing = document.querySelector('#scr-landing');
  if (!landing) return;
  const reduce = matchMedia('(prefers-reduced-motion: reduce)');
  const mobile = matchMedia('(max-width: 640px)');
  // Restored from 9267982: original 9–15 second paths, glow, stagger and sway.
  function atmosphere() {
    landing.querySelectorAll('.hbl-firefly-field').forEach(field => field.remove());
    const field = document.createElement('div');
    field.className = 'hbl-firefly-field'; field.setAttribute('aria-hidden', 'true');
    for (let i = 0; i < (mobile.matches ? 22 : 44); i++) {
      const light = document.createElement('i');
      light.style.cssText = `--x:${4 + (i * 37) % 92}%;--y:${2 + (i * 23) % 96}%;--size:${1.5 + i % 3}px;--duration:${9 + i % 7}s;--delay:-${i * 1.3}s;--sway:${i % 2 ? 18 : -18}px`;
      field.append(light);
    }
    landing.querySelector('.hbl-page').append(field);
  }
  atmosphere(); mobile.addEventListener('change', atmosphere);
  document.addEventListener('visibilitychange', () => landing.classList.toggle('hbl-paused', document.hidden));
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
})();
