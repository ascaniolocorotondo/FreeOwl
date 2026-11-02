"""Scarica la lista di server pubblicitari e traccianti di Peter Lowe
e la trasforma in regole di blocco per WebKit (formato content blocker).

Uso: python3 make_blocklist.py FreeOwl/blocklist.json
"""
import json
import re
import sys
import urllib.request

LIST_URL = "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=nohtml&showintro=0&mimetype=plaintext"

text = urllib.request.urlopen(LIST_URL, timeout=60).read().decode()
domains = sorted({d.strip().lower() for d in text.splitlines() if re.fullmatch(r"[a-z0-9.-]+\.[a-z]+", d.strip().lower())})
if len(domains) < 1000:
    sys.exit(f"Lista troppo corta ({len(domains)} domini): qualcosa non va")

rules = [
    {
        "trigger": {
            "url-filter": r"^[^:]+://+([^:/]+\.)?" + d.replace(".", r"\.") + "[:/]",
            "load-type": ["third-party"],
        },
        "action": {"type": "block"},
    }
    for d in domains
]

with open(sys.argv[1], "w") as f:
    json.dump(rules, f)
print(f"{len(rules)} regole di blocco")
