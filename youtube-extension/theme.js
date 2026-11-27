(() => {
  const preference = window.matchMedia('(prefers-color-scheme: dark)');
  const root = document.documentElement;

  function applyTheme() {
    const dark = preference.matches;
    if (root.hasAttribute('dark') !== dark) {
      root.toggleAttribute('dark', dark);
    }
  }

  // YouTube can restore its saved theme when navigating within the same tab.
  new MutationObserver(applyTheme).observe(root, {
    attributes: true,
    attributeFilter: ['dark'],
  });
  preference.addEventListener('change', applyTheme);
  applyTheme();
})();
