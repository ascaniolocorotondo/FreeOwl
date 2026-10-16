#!/usr/bin/env python3
"""
Free Owl - build per Linux.

Prende LibreWolf ufficiale per Linux (x86_64) e lo trasforma in Free Owl:
nome, logo, impostazioni, policy ed estensione del gufo. Nessuna compilazione.

Uso:
    python3 build_linux.py                   # ultima versione di LibreWolf
    python3 build_linux.py --version 158.0-1
    python3 build_linux.py --appimage        # crea anche l'AppImage (serve appimagetool)

Richiede Pillow (pip install pillow).
"""
import argparse
import hashlib
import io
import json
import re
import shutil
import subprocess
import tarfile
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image

BRAND = "Free Owl"
ROOT = Path(__file__).resolve().parent
CONFIG = ROOT / "config"
ASSETS = ROOT / "assets"
DOWNLOAD = ROOT / "download" / "linux"
DIST = ROOT / "dist-linux"
DL_BASE = "https://dl.librewolf.net/librewolf"
APPIMAGETOOL_URL = "https://github.com/AppImage/appimagetool/releases/download/1.9.0/appimagetool-x86_64.AppImage"

# Solo file di testo visibili all'utente (traduzioni), mai il codice.
LOCALE_TEXT = re.compile(r"^(localization/.+\.ftl|chrome/[^/]+/locale/.+\.(dtd|properties))$")

OMNI_ICONS = {
    "chrome/browser/content/branding/icon16.png": 16,
    "chrome/browser/content/branding/icon32.png": 32,
    "chrome/browser/content/branding/icon48.png": 48,
    "chrome/browser/content/branding/icon64.png": 64,
    "chrome/browser/content/branding/icon128.png": 128,
    "chrome/browser/content/branding/about.png": 192,
    "chrome/browser/content/branding/about-logo.png": 192,
    "chrome/browser/content/branding/about-logo@2x.png": 384,
    "chrome/browser/content/branding/about-logo-private.png": 192,
    "chrome/browser/content/branding/about-logo-private@2x.png": 384,
}

LAUNCHER = """#!/bin/sh
# Avvia Free Owl con il suo profilo (separato da un eventuale LibreWolf installato).
HERE="$(dirname "$(readlink -f "$0")")"
PROFILE="${FREEOWL_PROFILE:-$HOME/.freeowl}"
mkdir -p "$PROFILE"
exec "$HERE/librewolf" --name freeowl --class freeowl -profile "$PROFILE" "$@"
"""

DESKTOP = """[Desktop Entry]
Type=Application
Name=Free Owl
GenericName=Browser web
Comment=Naviga sul web rispettando la tua privacy
Exec={exec} %u
Icon=freeowl
Terminal=false
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
StartupWMClass=freeowl
StartupNotify=true
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=Nuova finestra
Exec={exec} --new-window %u

[Desktop Action new-private-window]
Name=Nuova finestra anonima
Exec={exec} --private-window %u
"""

INSTALL_SH = """#!/bin/sh
# Installa Free Owl solo per l'utente corrente (niente sudo).
set -e
HERE="$(dirname "$(readlink -f "$0")")"
DEST="$HOME/.local/share/freeowl"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons/hicolor/256x256/apps"

rm -rf "$DEST"
mkdir -p "$DEST" "$APPS" "$ICONS" "$HOME/.local/bin"
cp -a "$HERE/." "$DEST/"
cp "$HERE/freeowl.png" "$ICONS/freeowl.png"
sed "s|^Exec=freeowl|Exec=$DEST/freeowl|" "$HERE/freeowl.desktop" > "$APPS/freeowl.desktop"
ln -sf "$DEST/freeowl" "$HOME/.local/bin/freeowl"
update-desktop-database "$APPS" 2>/dev/null || true

echo "Free Owl installato! Lo trovi nel menu delle applicazioni (oppure scrivi: freeowl)."
"""

APPRUN = """#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/lib/freeowl/freeowl" "$@"
"""


def step(msg):
    print(f"==> {msg}", flush=True)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "FreeOwl-build"})
    with urllib.request.urlopen(req, timeout=300) as r:
        return r.read()


def latest_version():
    page = fetch("https://librewolf.net/installation/windows/").decode("utf-8", "replace")
    m = re.search(r"librewolf/([^/]+)/librewolf-[^\"']+-windows-x86_64-portable\.zip", page)
    if not m:
        raise SystemExit("Versione di LibreWolf non trovata su librewolf.net")
    return m.group(1)


def download(version):
    name = f"librewolf-{version}-linux-x86_64-package.tar.xz"
    path = DOWNLOAD / name
    DOWNLOAD.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        step(f"Scarico {name}")
        path.write_bytes(fetch(f"{DL_BASE}/{version}/{name}"))

    step("Verifico il checksum SHA256")
    sums = fetch(f"{DL_BASE}/{version}/sha256sums.txt").decode()
    expected = next((l.split()[0] for l in sums.splitlines() if l.endswith(name)), None)
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if expected != actual:
        path.unlink()
        raise SystemExit(f"Checksum NON valido per {name} (atteso {expected}, trovato {actual}). File eliminato.")
    return path


def png_bytes(logo, size):
    buf = io.BytesIO()
    logo.resize((size, size), Image.LANCZOS).save(buf, "PNG")
    return buf.getvalue()


def rewrite_omni(path, edit):
    """Riscrive un omni.ja applicando edit(nome, dati) -> nuovi dati oppure None."""
    tmp = path.with_suffix(".new")
    changed = 0
    with zipfile.ZipFile(path) as src, zipfile.ZipFile(tmp, "w") as dst:
        for info in src.infolist():
            data = src.read(info)
            new = edit(info.filename, data)
            if new is not None and new != data:
                data = new
                changed += 1
            out = zipfile.ZipInfo(info.filename, date_time=info.date_time)
            out.compress_type = info.compress_type
            out.external_attr = info.external_attr
            dst.writestr(out, data)
    tmp.replace(path)
    return changed


def rebrand_text(name, data):
    if LOCALE_TEXT.match(name) and b"LibreWolf" in data:
        return data.replace(b"LibreWolf", BRAND.encode())
    return None


def merge(base, over):
    for key, value in over.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            merge(base[key], value)
        else:
            base[key] = value


def make_tree(version, logo):
    out = DIST / "freeowl"
    step(f"Estraggo in {out}")
    if DIST.exists():
        shutil.rmtree(DIST)
    DIST.mkdir(parents=True)
    with tarfile.open(download(version)) as tar:
        tar.extractall(DIST, filter="tar")
    (DIST / "librewolf").rename(out)

    step(f"Applico il nome '{BRAND}'")
    for omni in (out / "browser" / "omni.ja", out / "omni.ja"):
        print(f"    {omni.relative_to(DIST)}: file modificati {rewrite_omni(omni, rebrand_text)}")

    step("Applico il logo")
    icons = {name: png_bytes(logo, size) for name, size in OMNI_ICONS.items()}
    rewrite_omni(out / "browser" / "omni.ja", lambda name, data: icons.get(name))
    for size in (16, 32, 48, 64, 128):
        (out / "browser" / "chrome" / "icons" / "default" / f"default{size}.png").write_bytes(png_bytes(logo, size))
    (out / "freeowl.png").write_bytes(png_bytes(logo, 256))

    step("Aggiungo le impostazioni Free Owl a librewolf.cfg")
    with open(out / "librewolf.cfg", "a", encoding="utf-8") as cfg:
        cfg.write("\n" + (CONFIG / "freeowl.cfg").read_text(encoding="utf-8"))

    step("Includo l'estensione Free Owl")
    ext_dir = out / "distribution" / "extensions"
    ext_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ext_dir / "freeowl@freeowl.local.xpi", "w", zipfile.ZIP_DEFLATED) as xpi:
        for f in sorted((ROOT / "extension").rglob("*")):
            if f.is_file():
                xpi.write(f, f.relative_to(ROOT / "extension").as_posix())

    step("Unisco le policy")
    pol_path = out / "distribution" / "policies.json"
    pol = json.loads(pol_path.read_text(encoding="utf-8"))
    merge(pol["policies"], json.loads((CONFIG / "policies.json").read_text(encoding="utf-8"))["policies"])
    pol["policies"].setdefault("SupportMenu", {})["Title"] = f"Supporto {BRAND}"
    pol_path.write_text(json.dumps(pol, indent=2, ensure_ascii=False), encoding="utf-8")

    step("Aggiungo avvio, collegamento e installatore")
    for name, text in (("freeowl", LAUNCHER), ("install.sh", INSTALL_SH)):
        (out / name).write_text(text, encoding="utf-8")
        (out / name).chmod(0o755)
    (out / "freeowl.desktop").write_text(DESKTOP.format(exec="freeowl"), encoding="utf-8")
    return out


def make_tarball(out, version):
    final = DIST / f"FreeOwl-{version}-linux-x86_64.tar.gz"
    step(f"Creo {final.name}")
    with tarfile.open(final, "w:gz") as tar:
        tar.add(out, arcname="freeowl")
    return final


def make_appimage(out, version, logo):
    appdir = DIST / "FreeOwl.AppDir"
    step("Preparo l'AppImage")
    shutil.copytree(out, appdir / "usr" / "lib" / "freeowl", symlinks=True)
    (appdir / "AppRun").write_text(APPRUN, encoding="utf-8")
    (appdir / "AppRun").chmod(0o755)
    (appdir / "freeowl.desktop").write_text(DESKTOP.format(exec="freeowl"), encoding="utf-8")
    (appdir / "freeowl.png").write_bytes(png_bytes(logo, 256))
    icon_dir = appdir / "usr" / "share" / "icons" / "hicolor" / "256x256" / "apps"
    icon_dir.mkdir(parents=True)
    (icon_dir / "freeowl.png").write_bytes(png_bytes(logo, 256))

    tool = DOWNLOAD / "appimagetool-x86_64.AppImage"
    if not tool.exists():
        step("Scarico appimagetool")
        tool.write_bytes(fetch(APPIMAGETOOL_URL))
        tool.chmod(0o755)

    final = DIST / f"FreeOwl-{version}-linux-x86_64.AppImage"
    step(f"Creo {final.name}")
    subprocess.run(
        [str(tool), "--no-appstream", str(appdir), str(final)],
        check=True,
        env={"ARCH": "x86_64", "APPIMAGE_EXTRACT_AND_RUN": "1", "PATH": "/usr/bin:/bin"},
    )
    return final


def main():
    parser = argparse.ArgumentParser(description="Costruisce Free Owl per Linux")
    parser.add_argument("--version", default="")
    parser.add_argument("--appimage", action="store_true")
    args = parser.parse_args()

    version = args.version or latest_version()
    print(f"    Versione LibreWolf: {version}")
    logo = Image.open(ASSETS / "logo.png").convert("RGBA")

    out = make_tree(version, logo)
    results = [make_tarball(out, version)]
    if args.appimage:
        results.append(make_appimage(out, version, logo))

    print(f"\nFatto! Free Owl per Linux ({version}):")
    for r in results:
        print(f"  {r}")


if __name__ == "__main__":
    main()
