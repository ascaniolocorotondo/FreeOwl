"use strict";

// ---------------------------------------------------------------- contatore tracker
// Una richiesta conta come "bloccata" quando fallisce prima di partire:
// - errori della protezione antitracciamento di Firefox (NS_ERROR_TRACKING_URI, ...)
// - richieste annullate da uBlock Origin prima ancora di inviare gli header.
const TRACKING_ERRORS = /TRACKING|FINGERPRINTING|CRYPTOMINING|SOCIALTRACKING|EMAILTRACKING/;
const sent = new Set();

const todayKey = () => new Date().toISOString().slice(0, 10);
let stats = { blockedTotal: 0, blockedToday: 0, blockedDay: todayKey() };
let dirty = false;

browser.storage.local.get(stats).then(saved => {
  stats = Object.assign(stats, saved);
  if (stats.blockedDay !== todayKey()) {
    stats.blockedToday = 0;
    stats.blockedDay = todayKey();
  }
});

function countBlocked() {
  if (stats.blockedDay !== todayKey()) {
    stats.blockedToday = 0;
    stats.blockedDay = todayKey();
  }
  stats.blockedTotal++;
  stats.blockedToday++;
  dirty = true;
}

setInterval(() => {
  if (dirty) {
    dirty = false;
    browser.storage.local.set(stats);
  }
}, 1500);

const filter = { urls: ["http://*/*", "https://*/*"] };

browser.webRequest.onSendHeaders.addListener(d => {
  sent.add(d.requestId);
}, filter);

browser.webRequest.onCompleted.addListener(d => {
  sent.delete(d.requestId);
}, filter);

browser.webRequest.onErrorOccurred.addListener(d => {
  const wasSent = sent.delete(d.requestId);
  if (d.type === "main_frame") {
    return;
  }
  if (TRACKING_ERRORS.test(d.error) || (!wasSent && d.thirdParty)) {
    countBlocked();
  }
}, filter);

// ---------------------------------------------------------------- Vola via
async function flyAway() {
  await browser.browsingData.remove({}, {
    cache: true,
    cookies: true,
    downloads: true,
    formData: true,
    history: true,
    indexedDB: true,
    localStorage: true,
    pluginData: true,
    serviceWorkers: true
  });
  const oldTabs = await browser.tabs.query({});
  await browser.tabs.create({});
  await browser.tabs.remove(oldTabs.map(t => t.id));
}

browser.runtime.onMessage.addListener(msg => {
  if (msg && msg.type === "flyAway") {
    return flyAway();
  }
  return undefined;
});
