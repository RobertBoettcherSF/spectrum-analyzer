#!/usr/bin/env python3
"""Embed sa.wasm as base64 into the single-file page.
usage: embed.py sa.wasm web/template.html docs/index.html

The page's build id is the short git commit this script was run on.
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
for needle in ("__WASM_BASE64__", "__WAV_PCM_JS__", "__FEEDBACK_JS__", "__BUILD_ID__"):
    if needle not in page:
        sys.exit("template has no " + needle + " placeholder")
here = os.path.dirname(os.path.abspath(__file__))


def page_js(name):
    text = open(os.path.join(here, name), encoding="utf-8").read()
    start = text.index("// PAGE-START\n") + len("// PAGE-START\n")
    end = text.index("// PAGE-END\n")
    return text[start:end].replace("export function ", "function ")


page = page.replace("__WAV_PCM_JS__", page_js("wav_pcm.mjs"))
page = page.replace("__FEEDBACK_JS__", page_js("feedback.mjs"))
page = page.replace("__BUILD_ID__", commit)
page = page.replace("__WASM_BASE64__", b64)
open(out, "w", encoding="utf-8").write(page)
print(f"wrote {out} ({len(b64)} base64 chars, source {commit})")
