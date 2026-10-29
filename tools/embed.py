#!/usr/bin/env python3
"""Embed sa.wasm, the WAV reader, and the GNATprove summary into one page.
usage: embed.py sa.wasm proof/gnatprove.out web/template.html docs/index.html
"""
import base64
import datetime
import json
import os
import re
import subprocess
import sys

wasm, prove, template, out = sys.argv[1:5]
text = open(prove, encoding="utf-8").read()
rows = {}
for line in text.splitlines():
    m = re.match(
        r"^(Data Dependencies|Flow Dependencies|Initialization|Non-Aliasing|"
        r"Run-time Checks|Assertions|Functional Contracts|LSP Verification|"
        r"Termination|Concurrency|Total)\s+(\S+)\s+(.*)$",
        line,
    )
    if not m:
        continue
    cells = re.split(r"\s{2,}", m.group(3).strip())

    def num(s):
        return 0 if s in (".", "") else int(s.split()[0])

    flow, provers, justified, unproved = (cells + ["."] * 4)[:4]
    rows[m.group(1)] = {
        "total": num(m.group(2)),
        "flow": num(flow),
        "provers": num(provers),
        "justified": num(justified),
        "unproved": num(unproved),
    }


def clean(*cats):
    return all(
        rows.get(c, {"unproved": 0, "justified": 0})["unproved"] == 0
        and rows.get(c, {"justified": 0})["justified"] == 0
        for c in cats
    )


units = re.search(r"Analyzed (\d+) units", text)
# Gold stays open on purpose. The contracts that exist are proved, and they
# are bounds and structural facts. They do not say the transform is a DFT.
levels = [
    ["Stone", "valid SPARK subset (window, FFT indexes, magnitude frame, STFT, carrier)", bool(units)],
    ["Bronze", "flow analysis: initialization and data dependencies",
     clean("Data Dependencies", "Flow Dependencies", "Initialization", "Non-Aliasing")],
    ["Silver", "no run-time errors in the SPARK subset; loops terminate",
     clean("Run-time Checks", "Termination")],
    ["Gold", "open: no contract says the transform is a DFT, the Hann gain is 1, or float matches a fixed-point model", False],
]
version = "unknown"
version_path = os.path.join(os.path.dirname(prove), "version.txt")
try:
    version = open(version_path, encoding="utf-8").read().strip()
except OSError:
    pass
honesty = [
    "SPARK subset: window, FFT index plan, magnitude framing, STFT hops, carrier bin and edges, Is_Power_Of_Two, To_DBFS.",
    "Silver is absence of run-time errors and termination. No pragma Annotate and no pragma Assume in src/.",
    "Trusted posts, bodies not proved: Sin and Cos in [-1, 1]; Log10 in [-4000, 4000]. Those are the platform elementary functions.",
    "SPARK_Mode Off, measured by the tone test and the demo smoke: complex arithmetic, the FFT butterfly, the twiddle, and 2|X|/sum(window).",
    "Not in SPARK: parabolic peak picker, demo signal, Analysis, the spectrum_api WASM glue, JavaScript, and the WAV reader.",
    "The pipeline is floating point, not a fixed-point proof. Agreement of the demo peaks and carrier edges is measured, native and WASM.",
    "GNAT Integer is 32-bit here and on wasm32. That is the integer model the proof used.",
]
proof = {
    "rows": rows,
    "levels": levels,
    "units": int(units.group(1)) if units else 0,
    "gnatprove": version,
    "assumes": len(re.findall(r"[1-9]\d* pragma Assume", text)),
    "honesty": honesty,
    "built": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
}
try:
    proof["commit"] = subprocess.check_output(
        ["git", "rev-parse", "--short", "HEAD"], text=True
    ).strip()
except (OSError, subprocess.CalledProcessError):
    proof["commit"] = "uncommitted"

b64 = base64.b64encode(open(wasm, "rb").read()).decode("ascii")
page = open(template, encoding="utf-8").read()
if "__WASM_BASE64__" not in page:
    sys.exit("template has no __WASM_BASE64__ placeholder")
if "__WAV_PCM_JS__" not in page:
    sys.exit("template has no __WAV_PCM_JS__ placeholder")
if "__PROOF_JSON__" not in page:
    sys.exit("template has no __PROOF_JSON__ placeholder")
here = os.path.dirname(os.path.abspath(__file__))
wav = open(os.path.join(here, "wav_pcm.mjs"), encoding="utf-8").read()
start = wav.index("// PAGE-START\n") + len("// PAGE-START\n")
end = wav.index("// PAGE-END\n")
page_js = wav[start:end].replace("export function ", "function ")
page = page.replace("__WAV_PCM_JS__", page_js)
page = page.replace("__WASM_BASE64__", b64)
page = page.replace("__PROOF_JSON__", json.dumps(proof))
open(out, "w", encoding="utf-8").write(page)
print(f"wrote {out} ({len(b64)} base64 chars, source {proof['commit']})")
