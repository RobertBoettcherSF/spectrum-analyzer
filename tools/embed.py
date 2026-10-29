#!/usr/bin/env python3
"""Embed sa.wasm as base64 into the single-file page.
usage: embed.py sa.wasm web/template.html docs/index.html
"""
import base64
import os
import subprocess
import sys

wasm, template, out = sys.argv[1:4]
b64 = base64.b64encode(open(wasm, "rb").read()).decode("ascii")
try:
    commit = subprocess.check_output(
        ["git", "rev-parse", "--short", "HEAD"], text=True
    ).strip()
except (OSError, subprocess.CalledProcessError):
    commit = "uncommitted"
page = open(template, encoding="utf-8").read()
if "__WASM_BASE64__" not in page:
    sys.exit("template has no __WASM_BASE64__ placeholder")
if "__WAV_PCM_JS__" not in page:
    sys.exit("template has no __WAV_PCM_JS__ placeholder")
here = os.path.dirname(os.path.abspath(__file__))
wav = open(os.path.join(here, "wav_pcm.mjs"), encoding="utf-8").read()
start = wav.index("// PAGE-START\n") + len("// PAGE-START\n")
end = wav.index("// PAGE-END\n")
page_js = wav[start:end].replace("export function ", "function ")
page = page.replace("__WAV_PCM_JS__", page_js)
page = page.replace("__WASM_BASE64__", b64)
open(out, "w", encoding="utf-8").write(page)
print(f"wrote {out} ({len(b64)} base64 chars, source {commit})")
