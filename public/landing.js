// Add approved native captures here when available. Empty values retain the explicitly labeled approved concept previews.
// Paths are relative to public/, e.g. /native-shots/home.webp.
(function () {
  const screenshots = { home: '', insight: '', plan: '', debt: '', goals: '', together: '' };
  const descriptions = {
    insight: 'Honeybun native From Bun with friendly insight explanations',
    home: 'Honeybun native Home showing Safe to Spend and From Bun',
    plan: 'Honeybun native Plan with budgets, upcoming bills, and forecast',
    debt: 'Honeybun native Debt Center with estimated payoff journey',
    goals: 'Honeybun native Goals with recorded progress',
    together: 'Honeybun native Together showing shared household planning'
  };
  document.querySelectorAll('#scr-landing [data-native-shot]').forEach((frame) => {
    const key = frame.dataset.nativeShot, src = screenshots[key];
    if (!src) return;
    const image = new Image();
    image.alt = descriptions[key]; image.width = 1206; image.height = 2622;
    image.className = 'hbl-native-capture';
    image.onload = () => { frame.querySelector('.hbl-screen').replaceChildren(image); frame.classList.add('has-capture'); frame.querySelector('figcaption').textContent = 'Honeybun native app'; };
    image.src = src;
  });
  const emberField = document.createElement('div');
  emberField.className = 'hbl-firefly-field';
  emberField.setAttribute('aria-hidden', 'true');
  // Small mixed particles distributed over the whole illustrated page.
  // Fewer on phones; CSS handles motion so there is no continuous JS loop.
  const particleCount = matchMedia('(max-width: 650px)').matches ? 60 : 100;
  for (let i = 0; i < particleCount; i++) {
    const particle = document.createElement('i');
    const kind = i % 10 === 0 ? 'leaf' : i % 5 === 0 ? 'sparkle' : i % 4 === 0 ? 'ember' : 'firefly';
    particle.className = `hbl-particle-${kind}`;
    particle.style.cssText = `--x:${3 + (i * 37) % 94}%;--y:${2 + (i * 23) % 96}%;--size:${2 + i % 3}px;--duration:${8 + i % 9}s;--delay:-${i * 1.3}s;--sway:${i % 2 ? 24 : -24}px;--spin:${i % 2 ? 35 : -35}deg`;
    if (kind === 'leaf') {
      particle.innerHTML = '<svg viewBox="0 0 24 24"><path d="m12 1 2 6 5-3-1 6 5 1-5 4 1 4-6-2v6h-2v-6l-6 2 1-4-5-4 5-1-1-6 5 3Z" fill="currentColor"/></svg>';
    }
    emberField.append(particle);
  }
  document.querySelector('.hbl-page')?.append(emberField);
  if (!matchMedia('(prefers-reduced-motion: reduce)').matches && 'IntersectionObserver' in window) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => { if (entry.isIntersecting) { entry.target.classList.add('hbl-enter'); observer.unobserve(entry.target); } });
    }, { threshold: .15 });
    document.querySelectorAll('.hbl-card').forEach((el) => observer.observe(el));
  }
  const utilitySummary = document.querySelector('.hbl-utility summary');
  utilitySummary?.addEventListener('click', (event) => {
    event.preventDefault();
    const details = utilitySummary.parentElement;
    details.open = !details.open;
  });
  // Preserve the web app's anchor behavior while honoring reduced motion.
  document.querySelectorAll('#scr-landing a[href^="#lp-"]:not([data-hbl-view])').forEach((link) => {
    link.onclick = (event) => {
      event.preventDefault();
      document.querySelector(link.getAttribute('href'))?.scrollIntoView({
        behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth'
      });
    };
  });
  const landing = document.querySelector('#scr-landing');
  const customViews = [...landing.querySelectorAll('.hbl-subpage')];
  const customLinks = [...landing.querySelectorAll('[data-hbl-view]')];
  function clearCustomViews() {
    customViews.forEach((section) => { section.hidden = true; });
    customLinks.forEach((link) => link.removeAttribute('aria-current'));
  }
  function topOfPage() {
    window.scrollTo({ top: 0, behavior: 'auto' });
  }
  customLinks.forEach((link) => link.addEventListener('click', (event) => {
    event.preventDefault();
    clearCustomViews();
    landing.querySelector('#lp-updates').hidden = true;
    landing.querySelector('#lp-rewards').hidden = true;
    const view = link.dataset.hblView;
    const section = landing.querySelector('#lp-' + view);
    section.hidden = false;
    landing.dataset.view = view;
    link.setAttribute('aria-current', 'page');
    topOfPage();
    section.querySelector('h1').focus({ preventScroll: true });
  }));
  landing.querySelectorAll('[data-hbl-back]').forEach((button) => button.addEventListener('click', () => {
    clearCustomViews();
    landing.removeAttribute('data-view');
    topOfPage();
    customLinks[0].focus({ preventScroll: true });
  }));
  landing.querySelector('#lpUpdatesLink').addEventListener('click', clearCustomViews);
  // Consistent disclosure behavior across the supported preview browsers.
  landing.querySelectorAll('.hbl-faq-list summary').forEach((summary) => summary.addEventListener('click', (event) => {
    event.preventDefault();
    summary.parentElement.open = !summary.parentElement.open;
  }));

})();
