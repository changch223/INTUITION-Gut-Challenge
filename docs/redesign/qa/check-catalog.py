#!/usr/bin/env python3
"""Checks BoomOrBonus/Localizable.xcstrings: every key is translated (state "translated", non-empty) in all six
languages, plural variations have the forms the language needs, and every translation uses the same format
specifiers as the key. Prints the string count per language. Exit code 1 on any problem."""
import json, os, re, sys
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..")
cat = json.load(open(os.path.join(root, "BoomOrBonus", "Localizable.xcstrings"), encoding="utf-8"))
LANGS = ["en", "ja", "ru", "zh-Hans", "zh-Hant", "zh-HK"]
FORMS = {"en": {"one", "other"}, "ru": {"one", "few", "many", "other"}}
def specs(s):
    found = [(m.group(1), m.group(2)) for m in re.finditer(r"%(?:(\d+)\$)?(lld|@|lf|ld)", s.replace("%%", ""))]
    if found and found[0][0] is None: found = [(str(i + 1), t) for i, (_, t) in enumerate(found)]
    return sorted(found)
count = {l: 0 for l in LANGS}
plural = {l: 0 for l in LANGS}
bad = []
for key, e in cat["strings"].items():
    loc = e.get("localizations", {})
    for l in LANGS:
        if l not in loc: bad.append(f"MISSING {l}: {key!r}"); continue
        d = loc[l]
        units = []
        if "stringUnit" in d:
            units = [d["stringUnit"]]
        elif "variations" in d:
            forms = d["variations"]["plural"]
            plural[l] += 1
            need = FORMS.get(l, {"other"})
            if not need <= set(forms): bad.append(f"PLURAL FORMS {l}: {key!r} has {sorted(forms)}")
            units = [f["stringUnit"] for f in forms.values()]
        for u in units:
            if u.get("state") != "translated" or not u.get("value", "").strip() and key.strip():
                bad.append(f"NOT TRANSLATED {l}: {key!r}")
            elif specs(u["value"]) != specs(key):
                bad.append(f"FORMAT {l}: {key!r} -> {u['value']!r}")
        if units: count[l] += 1
print("keys:", len(cat["strings"]))
for l in LANGS: print(f"  {l}: {count[l]} translated ({plural[l]} with plural variations)")
for b in bad: print(b)
print("OK" if not bad else f"FAILED ({len(bad)} problems)")
sys.exit(1 if bad else 0)
