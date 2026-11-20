#!/usr/bin/env python3
"""Checks the App Store metadata files in this folder against Apple's limits.
name / subtitle <= 30 characters, promotional text <= 170, description and What's New <= 4000,
keywords <= 100 bytes (UTF-8, commas included). Usage: python3 check-lengths.py"""
import glob, os, re, sys
LIM = {"App name": 30, "Subtitle": 30, "Promotional text": 170, "Description": 4000, "What's New in 2.0": 4000}
here = os.path.dirname(os.path.abspath(__file__))
bad = 0
for f in sorted(glob.glob(os.path.join(here, "*.md"))):
    if os.path.basename(f) in ("release-checklist.md", "README.md"): continue
    text = open(f, encoding="utf-8").read()
    secs = dict(re.findall(r"^## (.+?)(?: \(.*?\))?\n\n(.*?)(?=\n## |\Z)", text, re.S | re.M))
    out = []
    for name, lim in LIM.items():
        body = secs[name].strip()
        n = len(body)
        out.append(f"{name} {n}/{lim}")
        if n > lim: bad += 1; print("TOO LONG", f, name, n)
    kb = len(secs["Keywords"].strip().encode("utf-8"))
    out.append(f"Keywords {kb}/100 bytes")
    if kb > 100: bad += 1; print("TOO LONG", f, "Keywords", kb)
    print(os.path.basename(f), "|", " | ".join(out))
print("OK" if not bad else "FAILED")
sys.exit(1 if bad else 0)
