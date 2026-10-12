"use strict";

// Logica comune a nuova scheda e popup: contatore, Vola via, Modalità Notte.
const fmt = new Intl.NumberFormat("it-IT");

function showCounts(s) {
  const today = s.blockedDay === new Date().toISOString().slice(0, 10) ? s.blockedToday : 0;
  document.getElementById("total").textContent = fmt.format(s.blockedTotal || 0);
  document.getElementById("today").textContent = fmt.format(today || 0);
}

function showNight(on) {
  const btn = document.getElementById("night");
  btn.classList.toggle("on", on);
  btn.textContent = on ? "☀️ Modalità Notte: attiva" : "🌙 Modalità Notte";
}

browser.storage.local
  .get({ blockedTotal: 0, blockedToday: 0, blockedDay: "", nightMode: false })
  .then(s => {
    showCounts(s);
    showNight(s.nightMode);
  });

browser.storage.onChanged.addListener(() => {
  browser.storage.local
    .get({ blockedTotal: 0, blockedToday: 0, blockedDay: "", nightMode: false })
    .then(s => {
      showCounts(s);
      showNight(s.nightMode);
    });
});

document.getElementById("night").addEventListener("click", async () => {
  const { nightMode } = await browser.storage.local.get({ nightMode: false });
  await browser.storage.local.set({ nightMode: !nightMode });
});

// Vola via chiede conferma: primo clic arma il pulsante, secondo clic entro 4 secondi lo esegue.
const flyBtn = document.getElementById("flyAway");
let armed = null;
flyBtn.addEventListener("click", () => {
  if (!armed) {
    flyBtn.classList.add("confirm");
    flyBtn.textContent = "Cancello tutto? Clicca ancora";
    armed = setTimeout(() => {
      armed = null;
      flyBtn.classList.remove("confirm");
      flyBtn.textContent = "🦉 Vola via";
    }, 4000);
    return;
  }
  clearTimeout(armed);
  flyBtn.textContent = "🦉 In volo…";
  browser.runtime.sendMessage({ type: "flyAway" });
});
