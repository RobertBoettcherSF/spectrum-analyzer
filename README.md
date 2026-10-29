# Ada Spectrum Analyzer

A spectrum analyzer whose signal processing is Ada 2012, compiled to
WebAssembly and drawn by a single self-contained page. JavaScript does not
compute the transform. It asks the module for the spectrum, the waterfall,
the markers and the carrier edges, then paints them.

The demonstration signal is 10 seconds at 8 kHz: 50 Hz mains, harmonics,
a little noise, and a 216.67 Hz ripple-control telegram (`1011001110100101`).
The page opens on that take and streams it: Ada computes one STFT hop at
a time, and JavaScript only draws, so the waterfall scrolls and the
spectrum and the carrier timeline move. It plays through, then loops
until Stop. **Full analysis** is the one-shot of the same take (averaged
spectrum, markers, levels, the whole waterfall) and the picture freezes.
A 16-bit PCM `.wav` can be dropped, chosen, or pasted. That load is the
same one-shot freeze, not the scrolling demo. The page checks the
header, mixes stereo to mono, and copies the samples into the module.
Float, compressed, and other bit depths are refused on the page, as are
files shorter than one 4096-point frame or longer than 524288 samples
(about 10.9 s at 48 kHz, 65.5 s at 8 kHz). Sample rates run from 8 kHz to
192 kHz. The plot for a file goes to 2 kHz so a 1 kHz tone sits inside
the peak picker; the demo plot still stops at 1 kHz. The carrier box
defaults to 216.67 Hz. Click or tap the spectrum, or type a frequency,
to drop a readout marker on that bin. It shows the bin frequency and
dBFS and follows the live spectrum. Clear removes it. The M1–M6 labels
stay the peak list from a full analysis. Lock carrier retargets the
on/off timeline to the number in the carrier box. Lock marker retargets
it to the readout. The demo keeps scrolling, and a WAV stays a one-shot.

**Live page:** https://robertboettchersf.github.io/spectrum-analyzer/

Repo: https://github.com/RobertBoettcherSF/spectrum-analyzer

The module is embedded in the HTML, so `docs/index.html` also opens with no
server. Pages deploys from the `docs/` folder on `main` (`docs/.nojekyll`
keeps Jekyll from touching the file).

## What the Ada core reports

Native GNAT and the WebAssembly module return the same integers.

| Marker | Frequency | Level | |
|---|---:|---:|---|
| M1 | 49.98 Hz | −5.9 dBFS | |
| M2 | 100.05 Hz | −46.0 dBFS | |
| M3 | 149.98 Hz | −28.0 dBFS | |
| M4 | 216.67 Hz | −45.6 dBFS | carrier |
| M5 | 250.00 Hz | −32.1 dBFS | |
| M6 | 350.02 Hz | −40.0 dBFS | |

Hann, 4096-point FFT, resolution bandwidth 2.93 Hz, 39 averaged frames.
STFT 1024 / hop 256 (309 frames). Carrier bin 28 is 218.75 Hz; the level
is the strongest of that bin and its two neighbours. Threshold −63.6 dBFS.
Seven on pulses:

```
ON 0.48 s .. 1.06 s
ON 1.47 s .. 2.05 s
ON 2.46 s .. 3.55 s
ON 4.48 s .. 6.05 s
ON 6.50 s .. 7.04 s
ON 7.97 s .. 8.54 s
ON 8.99 s .. 9.54 s
```

A separate self-test, also inside the module, windows a bin-centred unit
sine with the same Hann and FFT. The peak magnitude is 1.000000 and the
two Hann shoulders are 0.500000. That is the check that the normalisation
(`2 |X[k]| / Σ window`) is the one the plain-Ada analyzer uses.

The plain-Ada CLI (`--demo`, GNAT’s Mersenne Twister, seed 42) prints the
same six frequencies, the same −42.0 dBFS carrier high, and the same seven
pulses within one hop. This demo uses a fixed linear-congruential noise
source of the same amplitude so the native binary and the WebAssembly
module match each other bit for bit. The carrier marker is −45.6 dBFS
rather than the CLI’s −45.7, and the threshold is −63.6 rather than −62.0.

## Layout

| Path | What it is |
|---|---|
| `src/dsp.ads` | sample type, complex arithmetic, `To_DBFS` |
| `src/dsp-window.adb` | Hann window |
| `src/dsp-fft.adb` | in-place radix-2 FFT |
| `src/dsp-magnitude.adb` | one windowed frame, amplitude-normalised |
| `src/dsp-peaks.adb` | local maxima and parabolic interpolation |
| `src/dsp-stft.adb` | waterfall frames and the carrier track |
| `src/dsp-carrier.adb` | threshold and on/off edges |
| `src/demo_signal.adb` | the 10 s demonstration waveform |
| `src/analysis.adb` | runs the pipeline on the demo or on PCM |
| `src/spectrum_api.adb` | C exports the page calls (`sa_*`), including the PCM buffer |
| `src/smoke.adb` | native checks, warnings as errors |
| `web/template.html` | the lab screen; `build.sh` fills in the module |
| `docs/index.html` | the built page (one file, no CDN) |
| `tools/get-toolchain.sh` | AdaWebPack 24 into `./toolchain` |
| `tools/wav_pcm.mjs` | 16-bit WAV check; stereo mixed to mono |
| `tools/embed.py` | base64 of `sa.wasm`, and the WAV reader, into the page |
| `tools/smoke_wasm.mjs` | the same numeric checks, plus a 1 kHz WAV |

## Build

Tools: GNAT and gprbuild for the native smoke test. AdaWebPack 24
(GNAT-LLVM) and `wasm-ld` for the browser, the same pair
[murmuration-spark](https://github.com/RobertBoettcherSF/murmuration-spark)
uses. The runtime is that compiler’s `rts-native`. It does not propagate
exceptions, so a failed check calls `Last_Chance_Handler` and the module
traps. `build.sh` passes `-gnatw.X` to keep the checks and silence only
that restriction warning. `./smoke` is built without that switch.

```sh
sudo apt install gnat gprbuild rpm2cpio cpio lld libedit2
# alr on PATH if libgnat-14 is not already installed
tools/get-toolchain.sh          # AdaWebPack 24 into ./toolchain
gprbuild -p -P spectrum.gpr && ./smoke
./build.sh                      # obj/wasm/sa.wasm -> docs/index.html
node tools/smoke_wasm.mjs obj/wasm/sa.wasm   # demo, then a 1 kHz WAV
```

`get-toolchain.sh` needs `alr` only when `libgnat-14.so` is missing. It
installs Alire’s `gnat_native=14.2.1` and copies that shared library next
to the compiler. The compiler is an Ada program; the library is for the
compiler, not for the WebAssembly module.

Then open `docs/index.html`, or serve the directory:

```sh
python3 -m http.server 8741 --directory docs
```

## Not in this version

An F9 dump and SPARK proofs. The algorithms are plain Ada.
