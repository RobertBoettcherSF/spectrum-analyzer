// Feedback report for the spectrum page. The page inlines the PAGE
// section; the smoke test imports the same functions.
//
// Ada is the source of the levels, the noise floor and the on/off edges.
// This file only reads those integers (microhertz, tenths of a dB,
// microseconds) and puts them in a JSON object a person can paste.
// It does not estimate a spectrum, a floor or an edge.

// PAGE-START
export function openStore(backing) {
  if (backing) return backing;
  try {
    const probe = "sa.probe";
    localStorage.setItem(probe, "1");
    localStorage.removeItem(probe);
    return localStorage;
  } catch (e) {
    const kept = new Map();
    return {
      getItem(key) { return kept.has(key) ? kept.get(key) : null; },
      setItem(key, value) { kept.set(key, String(value)); }
    };
  }
}

const SA_LOG = "sa.log";
const SA_CLEAN = "sa.clean";
const SA_BEAT = "sa.heartbeat";
const SA_LOG_MAX = 200;

export function sessionLoad(store) {
  let log = [];
  try {
    const parsed = JSON.parse(store.getItem(SA_LOG) || "[]");
    if (Array.isArray(parsed)) log = parsed;
  } catch (e) {
    log = [];
  }
  return {
    unclean: store.getItem(SA_CLEAN) === "0",
    previous: log.slice(),
    log
  };
}

export function sessionNote(store, log, ev, data) {
  const row = { t: new Date().toISOString(), ev };
  if (data !== undefined) row.data = data;
  log.push(row);
  if (log.length > SA_LOG_MAX) log.splice(0, log.length - SA_LOG_MAX);
  try {
    store.setItem(SA_LOG, JSON.stringify(log));
  } catch (e) {
    // A full store must not stop the analyzer. The in-memory log remains.
  }
  return log;
}

export function sessionBegin(store, session, build) {
  try {
    store.setItem(SA_CLEAN, "0");
  } catch (e) {
    // The session still runs when the browser refuses the store.
  }
  sessionNote(store, session.log, "start", { build, unclean: session.unclean });
}

export function sessionHeartbeat(store) {
  try {
    store.setItem(SA_BEAT, String(Date.now()));
  } catch (e) {
    // Same as the log: the page still runs if the store rejects the write.
  }
}

export function sessionHeartbeatIso(store) {
  const raw = store.getItem(SA_BEAT);
  if (!raw) return null;
  const ms = Number(raw);
  if (!Number.isFinite(ms)) return null;
  return new Date(ms).toISOString();
}

export function sessionCleanExit(store, log) {
  sessionNote(store, log, "clean exit");
  try {
    store.setItem(SA_CLEAN, "1");
  } catch (e) {
    // Same as the log: a refused write must not trap the page.
  }
}

export function feedbackReport(ada, ctx) {
  const markers = [];
  const nMark = ada.sa_markers();
  for (let i = 1; i <= nMark; i++) {
    const uhz = ada.sa_marker_uhz(i);
    const db10 = ada.sa_marker_db10(i);
    markers.push({
      id: "M" + i,
      hz: uhz / 1e6,
      dbfs: db10 / 10,
      uhz,
      db10,
      carrier: ada.sa_marker_carrier(i) === 1
    });
  }

  const edges = [];
  const nEdge = ada.sa_edges();
  for (let i = 1; i <= nEdge; i++) {
    const onUs = ada.sa_edge_on_us(i);
    const offUs = ada.sa_edge_off_us(i);
    edges.push({ onS: onUs / 1e6, offS: offUs / 1e6, onUs, offUs });
  }

  let userMarker = null;
  if (ctx.userBin !== undefined && ctx.userBin !== null) {
    const bin = ctx.userBin;
    const uhz = bin * ada.sa_df_uhz();
    const db10 = ada.sa_spec_db10(bin);
    userMarker = { bin, hz: uhz / 1e6, dbfs: db10 / 10, uhz, db10 };
  }

  let source = "";
  const nSrc = ada.sa_source_len();
  for (let i = 1; i <= nSrc; i++) {
    source += String.fromCharCode(ada.sa_source_char(i));
  }

  const floor10 = ada.sa_floor_db10();
  const thr10 = ada.sa_thr_db10();
  const lo10 = ada.sa_lo_db10();
  const hi10 = ada.sa_hi_db10();
  const carrierUHz = ada.sa_carrier_uhz();
  const rbwUHz = ada.sa_rbw_uhz();
  const dfUHz = ada.sa_df_uhz();
  const sdfUHz = ada.sa_sdf_uhz();
  const fmaxUHz = ada.sa_fmax_uhz();
  const durationUs = ada.sa_duration_us();

  return {
    kind: "spectrum-analyzer-feedback",
    build: ctx.build || "",
    time: ctx.time || new Date().toISOString(),
    browser: ctx.browser || "",
    screen: ctx.screen || null,
    mode: ctx.mode,
    file: ctx.file || null,
    source: source.replace(/\s+$/, ""),
    sampleRateHz: ada.sa_rate(),
    window: "Hann",
    fft: {
      n: ada.sa_fft_n(),
      rbwHz: rbwUHz / 1e6,
      rbwUHz,
      averages: ada.sa_avg_count(),
      bins: ada.sa_spec_bins(),
      dfHz: dfUHz / 1e6,
      dfUHz,
      fmaxHz: fmaxUHz / 1e6,
      fmaxUHz
    },
    stft: {
      n: ada.sa_stft_n(),
      hop: ada.sa_hop(),
      dfHz: sdfUHz / 1e6,
      dfUHz: sdfUHz,
      frames: ada.sa_tl_count(),
      rows: ada.sa_wf_rows(),
      cols: ada.sa_wf_cols()
    },
    durationS: durationUs / 1e6,
    durationUs,
    markers,
    noiseFloorDbfs: floor10 / 10,
    noiseFloorDb10: floor10,
    carrierHz: carrierUHz / 1e6,
    carrierUHz,
    carrierBin: ada.sa_carrier_bin(),
    thresholdDbfs: thr10 / 10,
    thresholdDb10: thr10,
    carrierLoDbfs: lo10 / 10,
    carrierLoDb10: lo10,
    carrierHiDbfs: hi10 / 10,
    carrierHiDb10: hi10,
    edges,
    userMarker,
    toneOk: ada.sa_tone_ok() === 1,
    tonePeak: ada.sa_tone_peak_ppm() / 1e6,
    tonePeakPpm: ada.sa_tone_peak_ppm(),
    errors: ctx.errors || [],
    events: ctx.events || []
  };
}
// PAGE-END
