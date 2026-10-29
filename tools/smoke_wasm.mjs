// Run the same integer API as src/smoke.adb against the WebAssembly module.
// usage: node tools/smoke_wasm.mjs obj/wasm/sa.wasm
import { readFileSync } from "node:fs";

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
if (failed) {
  console.log("WASM SMOKE FAILED");
  process.exit(1);
}
console.log("WASM SMOKE PASSED");
