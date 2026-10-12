"use strict";

// Modalità Notte: rende scuri i siti chiari invertendo i colori,
// ma rimette a posto foto e video. I siti già scuri non vengono toccati.
(() => {
  const STYLE_ID = "freeowl-night";
  const CSS = `
    html {
      filter: invert(1) hue-rotate(180deg) !important;
      background-color: #fff !important;
    }
    img, video, picture, canvas, iframe, embed, object, svg image,
    [style*="background-image"] {
      filter: invert(1) hue-rotate(180deg) !important;
    }
  `;

  function addStyle() {
    if (document.getElementById(STYLE_ID)) {
      return;
    }
    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = CSS;
    (document.head || document.documentElement).appendChild(style);
  }

  function removeStyle() {
    const style = document.getElementById(STYLE_ID);
    if (style) {
      style.remove();
    }
  }

  function isDark(color) {
    const m = color.match(/\d+(\.\d+)?/g);
    if (!m || (m.length === 4 && Number(m[3]) === 0)) {
      return null; // trasparente: non si sa
    }
    const [r, g, b] = m.map(Number);
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255 < 0.4;
  }

  // Se il sito è già scuro di suo, togliamo l'inversione.
  function skipIfAlreadyDark() {
    const style = document.getElementById(STYLE_ID);
    if (!style || !document.body) {
      return;
    }
    style.disabled = true;
    const dark =
      isDark(getComputedStyle(document.body).backgroundColor) ??
      isDark(getComputedStyle(document.documentElement).backgroundColor) ??
      false;
    style.disabled = false;
    if (dark) {
      removeStyle();
    }
  }

  function apply(on) {
    if (on) {
      addStyle();
      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", skipIfAlreadyDark, { once: true });
      } else {
        skipIfAlreadyDark();
      }
    } else {
      removeStyle();
    }
  }

  browser.storage.local.get({ nightMode: false }).then(s => apply(s.nightMode));
  browser.storage.onChanged.addListener(changes => {
    if (changes.nightMode) {
      apply(changes.nightMode.newValue);
    }
  });
})();
