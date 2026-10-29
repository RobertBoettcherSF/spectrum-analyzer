#!/bin/sh
# Compiles src/*.adb to WebAssembly (GNAT-LLVM / AdaWebPack 24) and embeds
# it into docs/index.html. JavaScript in web/template.html only draws.
set -e
cd "$(dirname "$0")"
T=$PWD/toolchain/usr
if [ ! -x "$T/bin/llvm-gcc" ]; then
  echo "Run tools/get-toolchain.sh first"
  exit 1
fi
if [ ! -f proof/gnatprove.out ]; then
  echo "Run ./prove.sh first"
  exit 1
fi
export LD_LIBRARY_PATH="$PWD/toolchain/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
LD=$(command -v wasm-ld || true)
if [ -z "$LD" ]; then
  LD=$(ls /usr/bin/wasm-ld-* 2>/dev/null | tail -1 || true)
fi
if [ -z "$LD" ]; then
  echo "wasm-ld not found (install the lld package)"
  exit 1
fi
rm -rf obj/wasm
mkdir -p obj/wasm docs
cd obj/wasm
# rts-native forbids exception propagation, so a check that fails calls
# Last_Chance_Handler instead of raising. -gnatwa warns about that
# (-gnatw.x) and -gnatwe would stop the build; -gnatw.X keeps the checks
# and silences only that runtime restriction. The native smoke binary
# is built without -gnatw.X, with ordinary exception propagation.
for F in \
  ../../src/dsp.adb \
  ../../src/dsp-window.adb \
  ../../src/dsp-fft.adb \
  ../../src/dsp-magnitude.adb \
  ../../src/dsp-peaks.adb \
  ../../src/dsp-carrier.adb \
  ../../src/dsp-stft.adb \
  ../../src/demo_signal.adb \
  ../../src/analysis.adb \
  ../../src/spectrum_api.adb
do
  echo "cc $F"
  "$T/bin/llvm-gcc" -c --target=wasm32 -O2 -gnat2012 -gnatwa -gnatwe -gnatw.X \
    --RTS="$T/lib/rts-native" -I../../src "$F"
done
EXPORTS="sa_analyze sa_analyze_pcm sa_pcm_ptr sa_pcm_cap sa_pcm_min \
sa_pcm_min_rate sa_pcm_max_rate sa_pcm_fmax_uhz sa_ready sa_tone_ok \
sa_tone_peak_ppm sa_tone_side_ppm sa_tone_far_ppm sa_rate sa_fft_n sa_stft_n \
sa_hop sa_avg_count sa_spec_bins sa_df_uhz sa_sdf_uhz sa_fmax_uhz \
sa_carrier_uhz sa_carrier_bin sa_duration_us sa_floor_db10 sa_thr_db10 \
sa_lo_db10 sa_hi_db10 sa_rbw_uhz sa_spec_db10 sa_markers sa_marker_uhz \
sa_marker_db10 sa_marker_carrier sa_wf_rows sa_wf_cols sa_wf sa_tl_count \
sa_tl_us sa_tl_db10 sa_tl_on sa_edges sa_edge_on_us sa_edge_off_us \
sa_source_len sa_source_char sa_live_begin sa_live_step sa_live_index \
sa_live_total"
set --
for E in $EXPORTS; do
  set -- "$@" "--export=$E"
done
# AdaWebPack's libgnat.a also contains a few host objects. wasm-ld warns
# about those even when it does not link them. Keep only wasm / bitcode.
python3 - "$T/lib/rts-native/adalib/libgnat.a" libgnat-wasm.a << 'PY'
import os, subprocess, sys
src, dst = sys.argv[1:]
os.makedirs("rts-pick", exist_ok=True)
members = subprocess.check_output(["ar", "t", src], text=True).split()
keep = []
for i, member in enumerate(members):
    data = subprocess.check_output(["ar", "p", src, member])
    if data.startswith(b"\0asm") or data.startswith(b"BC\xc0\xde"):
        path = os.path.join("rts-pick", f"{i:04d}-{member}")
        open(path, "wb").write(data)
        keep.append(path)
if not keep:
    sys.exit("no wasm objects in libgnat.a")
subprocess.check_call(["ar", "rcs", dst, *keep])
print(f"rts archive {len(keep)} wasm members, skipped {len(members) - len(keep)}")
PY
"$LD" --no-entry --export-memory --strip-all \
  "$@" \
  -z stack-size=8388608 \
  --initial-memory=67108864 \
  -o sa.wasm \
  *.o \
  libgnat-wasm.a
cd ../..
python3 tools/embed.py obj/wasm/sa.wasm proof/gnatprove.out web/template.html docs/index.html
echo "Built docs/index.html ($(wc -c < obj/wasm/sa.wasm) bytes of WebAssembly)"
