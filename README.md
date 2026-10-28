<p align="center">
  <img src="assets/logo.png" width="128" alt="Logo di Free Owl">
</p>

<h1 align="center">Free Owl 🦉</h1>

<p align="center">
  Un browser per Windows, Linux e Mac che rispetta la tua privacy, basato su <a href="https://librewolf.net">LibreWolf</a> e Firefox.
</p>

<p align="center">
  <a href="https://github.com/ascaniolocorotondo/FreeOwl/releases/latest"><img alt="Ultima versione" src="https://img.shields.io/github/v/release/ascaniolocorotondo/FreeOwl?label=versione&color=2ea44f"></a>
  <a href="https://github.com/ascaniolocorotondo/FreeOwl/releases"><img alt="Download" src="https://img.shields.io/github/downloads/ascaniolocorotondo/FreeOwl/total?label=download"></a>
  <img alt="Windows, Linux, Mac" src="https://img.shields.io/badge/Windows%20%C2%B7%20Linux%20%C2%B7%20Mac-64%20bit-555">
  <a href="LICENSE"><img alt="Licenza MPL 2.0" src="https://img.shields.io/badge/licenza-MPL%202.0-blue"></a>
</p>

<p align="center">
  <a href="https://ascaniolocorotondo.github.io/FreeOwl/"><strong>⬇️ Scarica Free Owl</strong></a> ·
  <a href="#come-si-installa">Come si installa</a> ·
  <a href="#-english">🇬🇧 English</a>
</p>

<p align="center">
  <img src="assets/screenshot.png" alt="La nuova scheda di Free Owl" width="800">
</p>

## Cosa ha di speciale

- 🕐 **Nuova scheda tutta sua**: orologio grande, data, saluto e ricerca veloce.
- 🦉 **Il gufo che ti protegge**: ti dice quanti tracker ha bloccato per te, in totale e oggi.
- 🪶 **Vola via**: un clic (più uno di conferma) e cancella cookie, cronologia, cache e schede aperte. Password e account restano.
- 🌙 **Modalità Notte**: rende scuri tutti i siti chiari, lasciando foto e video con i colori giusti.
- 🔍 **Niente motori che ti tracciano**: Google, Bing, Yahoo, Ecosia e simili sono rimossi. Di default c'è DuckDuckGo, e puoi scegliere tra Brave Search, Startpage, Mojeek e Qwant.
- 🍪 **Meno cookie**: i cookie di terze parti sono bloccati e i banner dei cookie vengono rifiutati da soli.
- 🔒 **HTTPS forzato** su tutti i siti.
- 🛡️ **uBlock Origin** già installato, con le liste italiane e quelle anti-banner dei cookie.
- 🔄 **Account Mozilla attivo**, per sincronizzare segnalibri e password (cifrati end-to-end).

E sotto, tutta la protezione di LibreWolf: niente telemetria, protezione dal fingerprinting, nessuna pubblicità nella nuova scheda.

## Come si installa

Tutto si scarica dai [**Download (Releases)**](../../releases/latest).

### 🪟 Windows

1. Scarica `FreeOwl-...-windows-x86_64-portable.zip`.
2. Estrai lo zip dove vuoi (per esempio in `Documenti`).
3. Apri `FreeOwl.exe`.

> **"Windows ha protetto il PC"?** È normale: Free Owl non ha una firma digitale a pagamento.
> Clicca **Ulteriori informazioni** e poi **Esegui comunque**.

Free Owl per Windows è *portable*: non serve installarlo e i tuoi dati restano nella cartella `Profiles`.

### 🐧 Linux

**Il modo più facile (AppImage):**

1. Scarica `FreeOwl-...-linux-x86_64.AppImage`.
2. Tasto destro → **Proprietà** → spunta **"Consenti di eseguire come programma"** (oppure nel terminale: `chmod +x FreeOwl-*.AppImage`).
3. Doppio clic per aprirlo.

**Oppure, per averlo nel menu delle applicazioni:**

```bash
tar -xzf FreeOwl-*-linux-x86_64.tar.gz
./freeowl/install.sh
```

Si installa solo per il tuo utente (niente `sudo`). I tuoi dati stanno in `~/.freeowl`, separati da un eventuale LibreWolf o Firefox.

### 🍎 Mac

1. Scarica `FreeOwl-...-macos-apple.dmg` se il tuo Mac ha un chip Apple (M1, M2, M3, M4…), oppure `FreeOwl-...-macos-intel.dmg` se ha un processore Intel. Lo vedi da mela in alto a sinistra → **Informazioni su questo Mac**.
2. Apri il `.dmg` e trascina **Free Owl** in **Applicazioni**.
3. Apri Free Owl.

> **macOS dice che non può verificare Free Owl?** È normale: Free Owl non ha la firma Apple a pagamento (99 $ l'anno).
> Vai in **Impostazioni di Sistema → Privacy e sicurezza**, scorri in basso e clicca **Apri comunque**. Va fatto solo la prima volta.
> Oppure, dal Terminale: `xattr -dr com.apple.quarantine "/Applications/Free Owl.app"`

I tuoi dati stanno in `~/Library/Application Support/Free Owl`, separati da un eventuale LibreWolf o Firefox.

## Aggiornamenti

Ogni giorno GitHub controlla in automatico se è uscita una nuova versione di LibreWolf. Se sì, costruisce e pubblica il nuovo Free Owl nei [Download](../../releases).

Per aggiornare:
- **Windows:** chiudi Free Owl, scarica il nuovo zip e copia la cartella `Profiles` della vecchia versione dentro quella nuova, così tieni segnalibri e impostazioni.
- **Linux:** scarica il nuovo AppImage (o rilancia `install.sh` con il nuovo `.tar.gz`). I tuoi dati in `~/.freeowl` restano dove sono.
- **Mac:** scarica il nuovo `.dmg` e sostituisci l'app in Applicazioni. I tuoi dati restano dove sono.

## Da sapere

- **Windows e Linux a 64 bit (x86_64), Mac Apple e Intel.**
- **Estensioni non firmate permesse**: servono per l'estensione del gufo, che è inclusa in Free Owl. Installa estensioni solo da [addons.mozilla.org](https://addons.mozilla.org).
- **Il contatore dei tracker è una stima**: conta le richieste di terze parti bloccate prima di partire (da uBlock Origin o dalla protezione antitracciamento).
- **Cookie di terze parti bloccati**: raramente qualche login tipo "Accedi con Google/Apple" su altri siti può non funzionare. Si risolve aggiungendo un'eccezione per quel sito (lucchetto nella barra degli indirizzi).

## Come funziona (per i curiosi)

Free Owl **non ricompila** Firefox. Gli script [`build.ps1`](build.ps1) (Windows), [`build_linux.py`](build_linux.py) (Linux) e [`build_macos.py`](build_macos.py) (Mac):

1. scaricano LibreWolf ufficiale e ne verificano l'impronta SHA256;
2. cambiano nome e logo in tutte le lingue e nelle icone;
3. aggiungono le impostazioni di [`config/freeowl.cfg`](config/freeowl.cfg) e le policy di [`config/policies.json`](config/policies.json);
4. includono l'estensione Free Owl ([`extension/`](extension));
5. creano i file pronti da scaricare.

Il robot di GitHub, oltre a costruire le versioni Linux e Mac, le avvia per davvero e controlla che l'estensione del gufo sia installata. Su Mac firma l'app con una firma "ad-hoc" gratuita.

Per costruirlo da solo:

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File build.ps1
```

```bash
# Linux (serve Pillow: pip install pillow)
python3 build_linux.py --appimage
```

```bash
# Mac (serve Pillow: pip install pillow)
python3 build_macos.py
```

## Ti piace Free Owl?

Lascia una ⭐ alla repo: aiuta altre persone a trovarlo. Hai trovato un problema o hai un'idea? Scrivila nelle [Issues](https://github.com/ascaniolocorotondo/FreeOwl/issues).

## 🇬🇧 English

**Free Owl** is a privacy-friendly browser for Windows, Linux and Mac, built on [LibreWolf](https://librewolf.net) and Firefox. It adds:

- 🕐 a custom **new tab** with a big clock, greeting and quick search;
- 🦉 an **owl counter** showing how many trackers were blocked, today and in total;
- 🪶 **"Fly away"**, a button that wipes cookies, history, cache and open tabs while keeping passwords and accounts;
- 🌙 a **Night mode** that darkens light websites without touching photos and videos;
- 🔍 private search engines only (DuckDuckGo by default; Brave Search, Startpage, Mojeek, Qwant);
- 🛡️ **uBlock Origin** preinstalled, third-party cookies blocked, cookie banners rejected automatically, HTTPS everywhere.

**Download** from the [latest release](https://github.com/ascaniolocorotondo/FreeOwl/releases/latest): a portable `.zip` for Windows, an `.AppImage` or `.tar.gz` for Linux, and a `.dmg` for Mac (Apple Silicon or Intel). The app is unsigned, so Windows SmartScreen and macOS Gatekeeper will warn you the first time. Choose "Run anyway" or "Open anyway".

New LibreWolf versions are picked up automatically every day by GitHub Actions. The interface of the owl extension is in Italian.

## Licenza e ringraziamenti

Free Owl è distribuito sotto la [Mozilla Public License 2.0](LICENSE).

È basato su [**LibreWolf**](https://librewolf.net) e su [**Mozilla Firefox**](https://www.mozilla.org/firefox/). Free Owl è un progetto indipendente: non è affiliato né approvato da LibreWolf o Mozilla. Firefox è un marchio di Mozilla Foundation.

Include [uBlock Origin](https://github.com/gorhill/uBlock) di Raymond Hill (GPLv3), installato dal sito ufficiale di Mozilla al primo avvio. Per cambiare l'icona dei `.exe` usa [rcedit](https://github.com/electron/rcedit) (MIT); per creare l'AppImage usa [appimagetool](https://github.com/AppImage/appimagetool) (MIT).
