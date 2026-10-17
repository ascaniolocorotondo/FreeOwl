#!/usr/bin/env python3
"""
Free Owl - build per macOS (da eseguire su un Mac: usa hdiutil e codesign).

Prende LibreWolf ufficiale per Mac e lo trasforma in "Free Owl.app":
nome, logo, impostazioni, policy ed estensione del gufo. Nessuna compilazione.
L'app viene firmata "ad-hoc" (gratis): al primo avvio macOS chiede di
confermare da Impostazioni di Sistema > Privacy e sicurezza > "Apri comunque".

Uso:
    python3 build_macos.py                          # ultima versione, Apple e Intel
    python3 build_macos.py --version 158.0-1 --arch arm64

Richiede Pillow (pip install pillow).
"""
import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

from PIL import Image

from build_linux import (
    BRAND,
    CONFIG,
    ASSETS,
    DL_BASE,
    OMNI_ICONS,
    ROOT,
    fetch,
    latest_version,
    merge,
    png_bytes,
    rebrand_text,
    rewrite_omni,
    step,
)

DOWNLOAD = ROOT / "download" / "macos"
DIST = ROOT / "dist-macos"
BUNDLE_ID = "io.github.ascaniolocorotondo.freeowl"

# Avvia Free Owl con il suo profilo, separato da un eventuale LibreWolf installato.
LAUNCHER = """#!/bin/sh
HERE="$(cd "$(dirname "$0")" && pwd)"
PROFILE="$HOME/Library/Application Support/Free Owl/Profile"
mkdir -p "$PROFILE"
exec "$HERE/librewolf" -profile "$PROFILE" "$@"
"""


def run(*cmd):
    subprocess.run(list(cmd), check=True)


def download(version, arch):
    name = f"librewolf-{version}-macos-{arch}-package.dmg"
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


def copy_app_from_dmg(dmg, dest):
    """Monta il .dmg in sola lettura e copia LibreWolf.app in dest."""
    mount = Path(tempfile.mkdtemp(prefix="librewolf-dmg-"))
    run("hdiutil", "attach", "-nobrowse", "-readonly", "-mountpoint", str(mount), str(dmg))
    try:
        apps = list(mount.glob("*.app"))
        if len(apps) != 1:
            raise SystemExit(f"Mi aspettavo una sola app nel .dmg, trovate: {apps}")
        run("ditto", str(apps[0]), str(dest))
    finally:
        run("hdiutil", "detach", str(mount), "-quiet")


def find_one(base, pattern):
    found = sorted(base.rglob(pattern))
    if not found:
        raise SystemExit(f"Non trovo {pattern} dentro {base}")
    return found[0]


def rebrand_strings_file(path):
    """InfoPlist.strings puo' essere UTF-16 o UTF-8: sostituisce il nome mantenendo la codifica."""
    raw = path.read_bytes()
    encoding = "utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8"
    text = raw.decode(encoding)
    if "LibreWolf" in text:
        path.write_bytes(text.replace("LibreWolf", BRAND).encode(encoding))


def make_app(version, arch, logo):
    out_dir = DIST / arch
    app = out_dir / f"{BRAND}.app"
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    step(f"Estraggo LibreWolf.app ({arch}) in {app}")
    copy_app_from_dmg(download(version, arch), app)
    contents = app / "Contents"
    resources = contents / "Resources"

    step(f"Applico il nome '{BRAND}'")
    for omni in (resources / "browser" / "omni.ja", resources / "omni.ja"):
        print(f"    {omni.relative_to(app)}: file modificati {rewrite_omni(omni, rebrand_text)}")
    for strings in resources.glob("*.lproj/InfoPlist.strings"):
        rebrand_strings_file(strings)

    step("Applico il logo")
    icons = {name: png_bytes(logo, size) for name, size in OMNI_ICONS.items()}
    rewrite_omni(resources / "browser" / "omni.ja", lambda name, data: icons.get(name))
    info_path = contents / "Info.plist"
    with open(info_path, "rb") as f:
        info = plistlib.load(f)
    icns_name = info.get("CFBundleIconFile", "librewolf")
    if not icns_name.endswith(".icns"):
        icns_name += ".icns"
    logo.save(resources / icns_name, format="ICNS")

    step("Aggiorno Info.plist")
    real_exe = info["CFBundleExecutable"]
    if real_exe != "librewolf":
        raise SystemExit(f"Eseguibile inatteso: {real_exe}")
    launcher = contents / "MacOS" / "freeowl"
    launcher.write_text(LAUNCHER, encoding="utf-8")
    launcher.chmod(0o755)
    info.update({
        "CFBundleName": BRAND,
        "CFBundleDisplayName": BRAND,
        "CFBundleIdentifier": BUNDLE_ID,
        "CFBundleExecutable": "freeowl",
    })
    with open(info_path, "wb") as f:
        plistlib.dump(info, f)

    step("Aggiungo le impostazioni Free Owl a librewolf.cfg")
    cfg = find_one(contents, "librewolf.cfg")
    with open(cfg, "a", encoding="utf-8") as f:
        f.write("\n" + (CONFIG / "freeowl.cfg").read_text(encoding="utf-8"))

    step("Includo l'estensione Free Owl")
    pol_path = find_one(contents, "policies.json")
    ext_dir = pol_path.parent / "extensions"
    ext_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ext_dir / "freeowl@freeowl.local.xpi", "w", zipfile.ZIP_DEFLATED) as xpi:
        for f in sorted((ROOT / "extension").rglob("*")):
            if f.is_file():
                xpi.write(f, f.relative_to(ROOT / "extension").as_posix())

    step("Unisco le policy")
    pol = json.loads(pol_path.read_text(encoding="utf-8"))
    merge(pol["policies"], json.loads((CONFIG / "policies.json").read_text(encoding="utf-8"))["policies"])
    pol["policies"].setdefault("SupportMenu", {})["Title"] = f"Supporto {BRAND}"
    pol_path.write_text(json.dumps(pol, indent=2, ensure_ascii=False), encoding="utf-8")

    step("Firmo l'app (firma ad-hoc gratuita)")
    run("codesign", "--force", "--deep", "--sign", "-", str(app))
    run("codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app))
    return app


def make_dmg(app, version, arch):
    label = "apple" if arch == "arm64" else "intel"
    final = DIST / f"FreeOwl-{version}-macos-{label}.dmg"
    step(f"Creo {final.name}")
    stage = Path(tempfile.mkdtemp(prefix="freeowl-dmg-"))
    run("ditto", str(app), str(stage / app.name))
    (stage / "Applicazioni").symlink_to("/Applications")
    if final.exists():
        final.unlink()
    run("hdiutil", "create", "-volname", BRAND, "-srcfolder", str(stage), "-ov", "-format", "UDZO", str(final))
    shutil.rmtree(stage)
    return final


def main():
    parser = argparse.ArgumentParser(description="Costruisce Free Owl per macOS")
    parser.add_argument("--version", default="")
    parser.add_argument("--arch", choices=["arm64", "x86_64", "all"], default="all")
    args = parser.parse_args()

    version = args.version or latest_version()
    print(f"    Versione LibreWolf: {version}")
    logo = Image.open(ASSETS / "logo.png").convert("RGBA")

    archs = ["arm64", "x86_64"] if args.arch == "all" else [args.arch]
    results = []
    for arch in archs:
        app = make_app(version, arch, logo)
        results.append(make_dmg(app, version, arch))

    print(f"\nFatto! Free Owl per Mac ({version}):")
    for r in results:
        print(f"  {r}")


if __name__ == "__main__":
    main()
