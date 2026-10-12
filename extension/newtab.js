"use strict";

const timeEl = document.getElementById("time");
const dateEl = document.getElementById("date");
const greetEl = document.getElementById("greeting");
const dateFmt = new Intl.DateTimeFormat("it-IT", { weekday: "long", day: "numeric", month: "long" });

function tick() {
  const now = new Date();
  timeEl.textContent =
    String(now.getHours()).padStart(2, "0") + ":" + String(now.getMinutes()).padStart(2, "0");
  dateEl.textContent = dateFmt.format(now);
  const h = now.getHours();
  greetEl.textContent =
    h < 5 ? "Buonanotte, gufo notturno 🦉" :
    h < 13 ? "Buongiorno" :
    h < 18 ? "Buon pomeriggio" :
    "Buonasera";
}
tick();
setInterval(tick, 1000);

// Cerca con il motore scelto al primo avvio (quello predefinito).
document.getElementById("search").addEventListener("submit", async e => {
  e.preventDefault();
  const query = document.getElementById("q").value.trim();
  if (!query) {
    return;
  }
  const tab = await browser.tabs.getCurrent();
  browser.search.search({ query, tabId: tab.id });
});
