// celestia-blur: blurred album cover behind the whole Spotify window, translucent panels on top.
(function celestiaBlur() {
  if (!window.Spicetify || !Spicetify.Player || !document.querySelector(".Root__top-container")) {
    setTimeout(celestiaBlur, 300);
    return;
  }

  const css = `
  .Root__top-container {
    background: #010808 !important;
    isolation: isolate;
  }
  #celestia-blur-bg, #celestia-blur-bg2 {
    position: fixed; inset: -120px; z-index: -1; pointer-events: none;
    background-position: center; background-size: cover;
    filter: blur(70px) saturate(1.6) brightness(0.75);
    transition: opacity 0.9s ease;
  }
  #celestia-blur-bg2 { opacity: 0; }
  #celestia-blur-tint {
    position: fixed; inset: 0; z-index: -1; pointer-events: none;
    background: rgba(1, 8, 8, 0.25);
  }

  /* panels: translucent glass */
  .Root__nav-bar, .Root__main-view, .Root__right-sidebar,
  .Root__nav-bar > *, .Root__main-view > *, .Root__right-sidebar > * {
    background-color: rgba(4, 19, 18, 0.22) !important;
    border-radius: 12px;
  }
  .Root__nav-bar, .Root__main-view, .Root__right-sidebar, .Root__now-playing-bar {
    --background-base: transparent !important;
  }
  .Root__nav-bar :is(nav, aside, section), .main-yourLibraryX-library, .main-yourLibraryX-libraryContainer {
    background: transparent !important;
  }
  .Root__nav-bar > *, .Root__main-view > *, .Root__right-sidebar > * { background-color: transparent !important; backdrop-filter: none; }
  .Root__now-playing-bar, .Root__top-bar, .Root__globalNav, #global-nav-bar {
    background: transparent !important;
  }
  .main-view-container, .main-view-container__scroll-node, .main-view-container__scroll-node-child,
  .main-entityHeader-backgroundColor, .main-actionBarBackground-background,
  .main-topBar-background, .main-home-homeHeader, .x-entityHeader-overlay {
    background: transparent !important;
    background-color: transparent !important;
  }
  `;
  const style = document.createElement("style");
  style.id = "celestia-blur-style";
  style.textContent = css;
  document.head.appendChild(style);

  const root = document.querySelector(".Root__top-container");
  const a = document.createElement("div"); a.id = "celestia-blur-bg";
  const b = document.createElement("div"); b.id = "celestia-blur-bg2";
  const t = document.createElement("div"); t.id = "celestia-blur-tint";
  root.prepend(t); root.prepend(b); root.prepend(a);

  let front = a, back = b, last = "";
  function coverUrl() {
    const item = Spicetify.Player.data?.item || {};
    const m = item.metadata || {};
    const imgs = item.images || item.album?.images || [];
    const biggest = imgs.length ? imgs.reduce((x, y) => ((y.width || 0) > (x.width || 0) ? y : x)) : null;
    const img = m.image_xlarge_url || m.image_large_url || m.image_url || biggest?.url || "";
    return img.startsWith("spotify:image:") ? "https://i.scdn.co/image/" + img.slice(14) : img;
  }
  function update() {
    const url = coverUrl();
    if (!url || url === last) return;
    last = url;
    back.style.backgroundImage = `url("${url}")`;
    back.style.opacity = "1";
    front.style.opacity = "0";
    [front, back] = [back, front];
  }
  Spicetify.Player.addEventListener("songchange", () => setTimeout(update, 100));
  update();
  setInterval(update, 2000);
})();
