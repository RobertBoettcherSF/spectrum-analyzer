// Run the same integer API as src/smoke.adb against the WebAssembly module,
// then a 1 kHz 16-bit WAV through the PCM buffer.
// usage: node tools/smoke_wasm.mjs obj/wasm/sa.wasm
import { readFileSync } from "node:fs";
import { encodeWav, encodeWavPcm16, parseWavPcm } from "./wav_pcm.mjs";

const buf = readFileSync(process.argv[2]);
const { instance } = await WebAssembly.instantiate(buf);
const a = instance.exports;
if (typeof a.sa_analyze !== "function") {
  console.error("missing sa_analyze");
  process.exit(1);
}
a.sa_analyze();

let failed = false;
function need(cond, what) {
  console.log((cond ? "  ok  " : "FAIL  ") + what);
  if (!cond) failed = true;
}
function peak(hz, tol, lo, hi) {
  const target = Math.round(hz * 1e6);
  const tolU = Math.round(tol * 1e6);
  for (let i = 1; i <= a.sa_markers(); i++) {
    if (Math.abs(a.sa_marker_uhz(i) - target) <= tolU &&
        a.sa_marker_db10(i) >= lo && a.sa_marker_db10(i) <= hi) return true;
  }
  return false;
}
function covers(sec) {
  const us = Math.round(sec * 1e6);
  for (let i = 1; i <= a.sa_edges(); i++) {
    if (a.sa_edge_on_us(i) <= us && a.sa_edge_off_us(i) >= us) return true;
  }
  return false;
}

console.log("tone", a.sa_tone_peak_ppm(), a.sa_tone_side_ppm(), a.sa_tone_far_ppm());
console.log("markers", a.sa_markers(), "edges", a.sa_edges(),
  "thr", a.sa_thr_db10(), "floor", a.sa_floor_db10());
for (let i = 1; i <= a.sa_markers(); i++) {
  console.log("M" + i, (a.sa_marker_uhz(i) / 1e6).toFixed(2),
    (a.sa_marker_db10(i) / 10).toFixed(1), a.sa_marker_carrier(i) ? "CARRIER" : "");
}
for (let i = 1; i <= a.sa_edges(); i++) {
  console.log("ON", (a.sa_edge_on_us(i) / 1e6).toFixed(2), (a.sa_edge_off_us(i) / 1e6).toFixed(2));
}

need(a.sa_tone_ok() === 1, "tone ok");
need(a.sa_tone_peak_ppm() >= 999000 && a.sa_tone_peak_ppm() <= 1001000, "peak ~ 1");
need(a.sa_rate() === 8000 && a.sa_fft_n() === 4096, "rate and fft");
need(a.sa_avg_count() === 39 && a.sa_spec_bins() === 513, "avg and bins");
need(a.sa_wf_rows() === 309 && a.sa_wf_cols() === 129, "waterfall shape");
need(a.sa_tl_count() === 309 && a.sa_carrier_bin() === 28, "timeline and carrier bin");
need(a.sa_markers() === 6, "six markers");
need(peak(50, 0.2, -70, -50), "50 Hz");
need(peak(100, 0.3, -520, -400), "100 Hz");
need(peak(150, 0.2, -310, -250), "150 Hz");
need(peak(216.67, 0.4, -520, -380), "216.67 Hz");
need(peak(250, 0.2, -360, -280), "250 Hz");
need(peak(350, 0.2, -450, -360), "350 Hz");
need(a.sa_edges() === 7, "seven edges");
need(covers(0.7) && covers(5.2) && covers(9.2), "on intervals");
need(!covers(1.2) && !covers(4.1), "off gaps");

const loose = { minSamples: 1, maxSamples: 100, minRate: 8000, maxRate: 192000 };
function reject(buf, lim, part, what) {
  const parsed = parseWavPcm(buf, lim);
  const ok = !parsed.ok && parsed.error.toLowerCase().includes(part);
  need(ok, what + (parsed.ok ? " (accepted)" : ": " + parsed.error));
}
reject(new ArrayBuffer(16), loose, "not a riff", "reject non-RIFF");
reject(encodeWav({
  format: 3, channels: 1, rate: 16000, bits: 32, align: 4,
  data: new Uint8Array(16)
}), loose, "float", "reject IEEE float");
reject(encodeWav({
  format: 1, channels: 1, rate: 16000, bits: 24, align: 3,
  data: new Uint8Array(24)
}), loose, "24-bit", "reject 24-bit PCM");
reject(encodeWav({
  format: 6, channels: 1, rate: 16000, bits: 8, align: 1,
  data: new Uint8Array(8)
}), loose, "not linear pcm", "reject A-law");
reject(encodeWavPcm16(16000, 1, new Int16Array(101)), loose, "too long", "reject over the cap");
reject(encodeWavPcm16(16000, 1, new Int16Array(100)), {
  minSamples: 4096, maxSamples: 524288, minRate: 8000, maxRate: 192000
}, "too short", "reject a short WAV");
reject(encodeWav({
  format: 1, channels: 6, rate: 16000, bits: 16, align: 12,
  data: new Uint8Array(12 * 8)
}), loose, "6 channels", "reject six channels");

{
  const n = 8;
  const inter = new Int16Array(n * 2);
  for (let i = 0; i < n; i++) {
    inter[i * 2] = 1000;
    inter[i * 2 + 1] = 3000;
  }
  const mixed = parseWavPcm(encodeWavPcm16(16000, 2, inter), loose);
  need(mixed.ok && mixed.mixed && mixed.samples.length === n, "stereo parses");
  need(mixed.ok && mixed.samples.every(s => s === 2000), "stereo mixes to the mean");
}

const rate = 16000;
const toneN = rate;
const mono = new Int16Array(toneN);
const stereo = new Int16Array(toneN * 2);
for (let i = 0; i < toneN; i++) {
  const s = Math.round(Math.sin(2 * Math.PI * 1000 * i / rate) * 32767 * 0.5);
  mono[i] = s;
  stereo[i * 2] = s;
  stereo[i * 2 + 1] = s;
}
const liveLimits = {
  minSamples: a.sa_pcm_min(),
  maxSamples: a.sa_pcm_cap(),
  minRate: a.sa_pcm_min_rate(),
  maxRate: a.sa_pcm_max_rate()
};
const wav = parseWavPcm(encodeWavPcm16(rate, 2, stereo), liveLimits);
need(wav.ok && wav.mixed && wav.frames === toneN, "1 kHz stereo WAV accepted");
need(wav.ok && wav.samples.every((s, i) => s === mono[i]), "identical channels mix to the tone");

need(a.sa_analyze_pcm(1000, toneN, 216670000) === 1, "wasm rejects a low rate");
need(a.sa_rate() === 8000 && a.sa_markers() === 6, "rejected PCM leaves the demo");
need(a.sa_analyze_pcm(rate, 100, 216670000) === 2, "wasm rejects a short buffer");
need(a.sa_analyze_pcm(rate, a.sa_pcm_cap() + 1, 216670000) === 3, "wasm rejects a long buffer");
need(a.sa_analyze_pcm(rate, toneN, 0) === 4, "wasm rejects carrier 0");

const ptr = a.sa_pcm_ptr();
need(ptr > 0 && (ptr & 1) === 0 && !!a.memory, "pcm pointer is an aligned memory offset");
if (wav.ok && a.memory && ptr > 0) {
new Int16Array(a.memory.buffer, ptr, wav.samples.length).set(wav.samples);
const uhz = Math.round(216.67 * 1e6);
let st = a.sa_analyze_pcm(rate, wav.frames, uhz);
need(st === 0, "wasm analyzes the 1 kHz WAV");
need(a.sa_rate() === rate && a.sa_duration_us() === 1_000_000, "wav rate and length");
need(peak(1000, 0.5, -80, -40), "wav peak at 1 kHz near -6 dBFS");
need(a.sa_tone_ok() === 1, "self-test still passes");
let carriers = 0;
for (let i = 1; i <= a.sa_markers(); i++) if (a.sa_marker_carrier(i) === 1) carriers++;
need(carriers === 0, "default carrier is not a peak of the tone");
for (let i = 1; i <= a.sa_markers(); i++) {
  console.log("pcm M" + i, (a.sa_marker_uhz(i) / 1e6).toFixed(2),
    (a.sa_marker_db10(i) / 10).toFixed(1));
}
st = a.sa_analyze_pcm(rate, wav.frames, Math.round(1000 * 1e6));
need(st === 0 && peak(1000, 0.5, -80, -40), "carrier field locks onto 1 kHz");
carriers = 0;
for (let i = 1; i <= a.sa_markers(); i++) if (a.sa_marker_carrier(i) === 1) carriers++;
need(carriers === 1 && a.sa_edges() === 0, "one carrier marker, no pulses");
need(a.sa_carrier_uhz() === 1_000_000_000, "reported carrier is 1000 Hz");
need(a.sa_hi_db10() >= -80 && a.sa_hi_db10() <= -40, "carrier level near -6 dBFS");
}

if (failed) {
  console.log("WASM SMOKE FAILED");
  process.exit(1);
}
console.log("WASM SMOKE PASSED");
