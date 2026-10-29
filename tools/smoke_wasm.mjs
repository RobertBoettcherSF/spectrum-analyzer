// Run the same integer API as src/smoke.adb against the WebAssembly module,
// then a 1 kHz 16-bit WAV through the PCM buffer.
// usage: node tools/smoke_wasm.mjs obj/wasm/sa.wasm
import { readFileSync } from "node:fs";
import { encodeWav, encodeWavPcm16, parseWavPcm } from "./wav_pcm.mjs";
import {
  feedbackReport,
  sessionBegin,
  sessionCleanExit,
  sessionLoad,
  sessionNote
} from "./feedback.mjs";

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

{
  const marks = [];
  for (let i = 1; i <= a.sa_markers(); i++) marks.push(a.sa_marker_uhz(i));
  const wf = a.sa_wf(100, 28);
  const thr = a.sa_thr_db10();
  need(a.sa_set_carrier(0) === 4, "wasm rejects carrier lock 0");
  need(a.sa_set_carrier(Math.round(50 * 1e6)) === 0, "wasm locks carrier to 50 Hz");
  need(a.sa_carrier_uhz() === Math.round(50 * 1e6), "wasm reports 50 Hz");
  need(a.sa_markers() === 6, "wasm lock keeps six peaks");
  let same = true;
  for (let i = 1; i <= 6; i++) if (a.sa_marker_uhz(i) !== marks[i - 1]) same = false;
  need(same, "wasm peak frequencies unchanged");
  need(a.sa_marker_carrier(1) === 1 && a.sa_marker_carrier(4) === 0,
    "wasm M1 is the locked carrier");
  need(a.sa_wf(100, 28) === wf, "wasm lock leaves the waterfall");
  need(a.sa_set_carrier(Math.round(216.67 * 1e6)) === 0, "wasm locks back to 216.67");
  need(a.sa_carrier_bin() === 28 && a.sa_edges() === 7, "wasm pulses restored");
  need(a.sa_thr_db10() === thr, "wasm threshold restored");
  need(a.sa_marker_carrier(4) === 1, "wasm M4 is the carrier again");
  const full = feedbackReport(a, {
    build: "smoke",
    mode: "full",
    userBin: null,
    errors: [],
    events: [{ ev: "full" }],
    time: "2026-10-29T00:00:00.000Z"
  });
  need(full.kind === "spectrum-analyzer-feedback" && full.build === "smoke", "f9 full build");
  need(full.mode === "full" && full.file === null, "f9 full mode");
  need(full.sampleRateHz === 8000 && full.fft.n === 4096 && full.fft.averages === 39, "f9 full fft");
  need(full.stft.n === 1024 && full.stft.hop === 256 && full.stft.frames === 309, "f9 full stft");
  need(full.markers.length === 6, "f9 full M1-M6");
  let marksOk = true;
  let carrierMarks = 0;
  for (let i = 1; i <= full.markers.length; i++) {
    const m = full.markers[i - 1];
    if (m.id !== "M" + i || m.db10 !== a.sa_marker_db10(i) || m.uhz !== a.sa_marker_uhz(i)) {
      marksOk = false;
    }
    if (m.carrier) carrierMarks++;
    if (m.carrier !== (a.sa_marker_carrier(i) === 1)) marksOk = false;
    if (m.dbfs !== m.db10 / 10 || m.hz !== m.uhz / 1e6) marksOk = false;
  }
  need(marksOk, "f9 marker levels are Ada's integers");
  need(carrierMarks === 1 && full.markers[3].carrier, "f9 M4 is the carrier");
  need(full.edges.length === 7, "f9 seven edges");
  let edgesOk = true;
  for (let i = 1; i <= full.edges.length; i++) {
    const e = full.edges[i - 1];
    if (e.onUs !== a.sa_edge_on_us(i) || e.offUs !== a.sa_edge_off_us(i)) edgesOk = false;
    if (e.onS !== e.onUs / 1e6 || e.offS !== e.offUs / 1e6) edgesOk = false;
  }
  need(edgesOk, "f9 edges are Ada's integers");
  need(full.noiseFloorDb10 === a.sa_floor_db10() && full.noiseFloorDbfs === full.noiseFloorDb10 / 10, "f9 floor is Ada's");
  need(full.carrierUHz === a.sa_carrier_uhz() && full.thresholdDb10 === a.sa_thr_db10(), "f9 carrier and threshold");
  need(full.userMarker === null, "f9 user marker omitted when unset");
  need(full.events.length === 1 && full.events[0].ev === "full", "f9 event log is packaged");
}

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
{
  const df = a.sa_df_uhz();
  const bin = Math.round(1_000_000_000 / df);
  const wavReport = feedbackReport(a, {
    build: "smoke",
    mode: "WAV",
    file: "tone.wav",
    userBin: bin,
    errors: [],
    events: [{ ev: "wav" }],
    time: "2026-10-29T00:00:00.000Z"
  });
  need(wavReport.mode === "WAV" && wavReport.file === "tone.wav", "f9 wav mode");
  need(wavReport.sampleRateHz === rate && wavReport.durationUs === 1_000_000, "f9 wav rate");
  need(wavReport.fft.n === 4096 && wavReport.stft.n === 1024 && wavReport.stft.hop === 256, "f9 wav settings");
  need(wavReport.carrierUHz === 1_000_000_000 && wavReport.carrierHz === 1000, "f9 wav carrier");
  need(wavReport.noiseFloorDb10 === a.sa_floor_db10(), "f9 wav floor is Ada's");
  need(wavReport.edges.length === a.sa_edges(), "f9 wav edges are Ada's");
  let packed = true;
  let sawTone = false;
  for (let i = 1; i <= a.sa_markers(); i++) {
    const m = wavReport.markers[i - 1];
    if (!m || m.db10 !== a.sa_marker_db10(i) || m.uhz !== a.sa_marker_uhz(i)) packed = false;
    if (m && Math.abs(m.hz - 1000) < 0.5 && m.db10 === a.sa_marker_db10(i)) sawTone = true;
  }
  need(packed && sawTone && wavReport.markers.length === a.sa_markers(), "f9 wav peaks are Ada's");
  const pin = wavReport.userMarker;
  need(pin && pin.bin === bin && pin.db10 === a.sa_spec_db10(bin) && pin.uhz === bin * df, "f9 wav user marker");
}
}

a.sa_analyze();
const savedWf = a.sa_wf(100, 28);
const savedTl = a.sa_tl_db10(40);
const savedThr = a.sa_thr_db10();
const savedEdges = a.sa_edges();
const savedOn = a.sa_edge_on_us(1);
let onAt = -1;
let offAt = -1;
for (let i = 0; i < a.sa_tl_count(); i++) {
  if (onAt < 0 && a.sa_tl_on(i) === 1) onAt = i;
  if (onAt >= 0 && i > onAt + 5 && a.sa_tl_on(i) === 0) { offAt = i; break; }
}
need(onAt >= 0 && offAt > onAt, "on hop then off hop");
const total = a.sa_live_begin();
need(total === 309, "live begin 309");
need(a.sa_live_index() === -1, "live index before first hop");
need(a.sa_markers() === 0, "live clears markers");
let step = a.sa_live_step();
need(step === 0, "first hop");
let onSpec = -2000;
let offSpec = -2000;
let last = 0;
let liveReport = null;
let liveDb = 0;
let liveOn = 0;
let liveEdges = -1;
let liveFloor = 0;
let liveCarrier = 0;
for (;;) {
  step = a.sa_live_step();
  if (step < 0) break;
  if (step === onAt) onSpec = a.sa_spec_db10(a.sa_carrier_bin());
  else if (step === offAt) offSpec = a.sa_spec_db10(a.sa_carrier_bin());
  if (step === 40) {
    const bin = a.sa_carrier_bin();
    liveDb = a.sa_spec_db10(bin);
    liveOn = a.sa_edge_on_us(1);
    liveEdges = a.sa_edges();
    liveFloor = a.sa_floor_db10();
    liveCarrier = a.sa_carrier_uhz();
    liveReport = feedbackReport(a, {
      build: "smoke",
      mode: "live demo",
      userBin: bin,
      errors: [],
      events: [{ ev: "play" }],
      time: "2026-10-29T00:00:00.000Z"
    });
  }
  last = step;
}
need(liveReport && liveReport.mode === "live demo", "f9 after demo scroll");
need(liveReport && liveReport.sampleRateHz === 8000, "f9 live rate");
need(liveReport && liveReport.fft.n === 4096 && liveReport.stft.n === 1024 && liveReport.stft.hop === 256, "f9 live fft/stft");
need(liveReport && liveReport.markers.length === 0, "f9 live has no averaged peaks yet");
need(liveReport && liveReport.stft.frames === 41, "f9 live frame count while scrolling");
need(liveReport && liveEdges >= 1 && liveReport.edges.length === liveEdges && liveReport.edges[0].onUs === liveOn, "f9 live edges are Ada's");
need(liveReport && liveReport.noiseFloorDb10 === liveFloor && liveFloor === -2000, "f9 live floor is Ada's unset value");
need(liveReport && liveReport.userMarker && liveReport.userMarker.db10 === liveDb, "f9 live user marker is Ada's");
need(liveReport && liveReport.carrierUHz === liveCarrier, "f9 live carrier is Ada's");
need(last === 308 && a.sa_live_step() === -1, "live stops after the last hop");
need(onSpec > offSpec + 60, "live spectrum falls when the carrier drops");
need(a.sa_wf_rows() === 309 && a.sa_wf_cols() === 129, "live waterfall shape");
need(a.sa_spec_bins() === 129, "live spectrum is one STFT");
need(a.sa_wf(100, 28) === savedWf, "live waterfall matches one-shot");
need(a.sa_tl_db10(40) === savedTl, "live level matches one-shot");
need(a.sa_edges() === savedEdges && a.sa_edge_on_us(1) === savedOn, "live edges");
need(a.sa_thr_db10() === savedThr, "live threshold");
need(a.sa_tone_ok() === 1, "tone still ok");

{
  function memoryStore() {
    const kept = new Map();
    return {
      getItem(key) { return kept.has(key) ? kept.get(key) : null; },
      setItem(key, value) { kept.set(key, String(value)); }
    };
  }
  const store = memoryStore();
  const first = sessionLoad(store);
  need(!first.unclean && first.previous.length === 0, "fresh session is clean");
  sessionBegin(store, first, "smoke");
  sessionNote(store, first.log, "play", { mode: "live demo" });
  sessionNote(store, first.log, "wasm trap", "unreachable");
  const second = sessionLoad(store);
  need(second.unclean, "unclean session is offered on the next load");
  need(second.previous.some(e => e.ev === "play") && second.previous.some(e => e.ev === "wasm trap"), "last events survive");
  need(!second.previous.some(e => e.ev === "clean exit"), "unclean log has no clean exit");
  sessionBegin(store, second, "smoke");
  sessionCleanExit(store, second.log);
  const third = sessionLoad(store);
  need(!third.unclean && third.previous.some(e => e.ev === "clean exit"), "clean exit stays clean");
  need(third.previous.length <= 200, "event log stays bounded");
}

{
  const page = readFileSync(new URL("../web/template.html", import.meta.url), "utf8");
  need(page.includes('id="feedback"'), "visible Feedback control");
  need(page.includes('e.key !== "F9"'), "F9 downloads the report");
  need(page.includes("feedbackReport(ada"), "page packages Ada through feedbackReport");
  need(page.includes('id="sessionDl"'), "unclean session offers the last events");
  need(page.includes("__BUILD_ID__"), "build id is filled at embed time");
}

if (failed) {
  console.log("WASM SMOKE FAILED");
  process.exit(1);
}
console.log("WASM SMOKE PASSED");
