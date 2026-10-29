// 16-bit PCM WAV reader. The page inlines the PAGE section; the smoke
// test imports the whole module. Stereo is mixed to mono here. Ada
// receives one int16 channel.

// PAGE-START
export function parseWavPcm(buffer, limits) {
  const view = new DataView(buffer);
  if (buffer.byteLength < 12) {
    return wavError("This file is too small to be a WAV.");
  }
  if (wavAscii(view, 0, 4) !== "RIFF" || wavAscii(view, 8, 4) !== "WAVE") {
    return wavError(
      "This file is not a RIFF WAVE. Choose an uncompressed 16-bit PCM .wav.");
  }

  let off = 12;
  let fmt = null;
  let dataOff = -1;
  let dataSize = 0;
  while (off + 8 <= buffer.byteLength) {
    const id = wavAscii(view, off, 4);
    const size = view.getUint32(off + 4, true);
    const start = off + 8;
    if (size > buffer.byteLength - start) {
      return wavError(
        "This WAV is truncated. The " + id.trim() + " chunk is longer than the file.");
    }
    if (id === "fmt ") {
      if (size < 16) return wavError("This WAV has a truncated format chunk.");
      fmt = {
        format: view.getUint16(start, true),
        channels: view.getUint16(start + 2, true),
        rate: view.getUint32(start + 4, true),
        align: view.getUint16(start + 12, true),
        bits: view.getUint16(start + 14, true)
      };
    } else if (id === "data" && dataOff < 0) {
      dataOff = start;
      dataSize = size;
    }
    const next = start + size + (size & 1);
    if (next < off) return wavError("This WAV chunk size is not usable.");
    off = next;
  }

  if (!fmt) return wavError("This WAV has no format chunk.");
  if (dataOff < 0) return wavError("This WAV has no data chunk.");
  if (fmt.format === 3) {
    return wavError(
      "This WAV is IEEE float, not 16-bit integer PCM. Export it as 16-bit PCM and try again.");
  }
  if (fmt.format !== 1) {
    return wavError(
      "This WAV is not linear PCM (format code " + fmt.format +
      "). Float, A-law, µ-law and compressed files are not accepted.");
  }
  if (fmt.bits !== 16) {
    return wavError(
      "This WAV is " + fmt.bits + "-bit PCM. Only 16-bit PCM is accepted.");
  }
  if (fmt.channels !== 1 && fmt.channels !== 2) {
    return wavError(
      "This WAV has " + fmt.channels + " channels. Only mono or stereo is accepted.");
  }
  if (fmt.align !== fmt.channels * 2) {
    return wavError(
      "This WAV has an unexpected block alignment. Only packed 16-bit PCM is accepted.");
  }
  if (fmt.rate < limits.minRate || fmt.rate > limits.maxRate) {
    return wavError(
      "Sample rate " + fmt.rate + " Hz is outside " +
      limits.minRate + " .. " + limits.maxRate + " Hz.");
  }
  if (dataSize % fmt.align !== 0) {
    return wavError("The data chunk is not a whole number of frames.");
  }
  const frames = dataSize / fmt.align;
  if (frames < limits.minSamples) {
    return wavError(
      "This WAV is too short: " + frames + " samples. The analyzer needs at least " +
      limits.minSamples + " samples (one FFT frame).");
  }
  if (frames > limits.maxSamples) {
    const secs = (frames / fmt.rate).toFixed(2);
    const maxSecs = (limits.maxSamples / fmt.rate).toFixed(2);
    return wavError(
      "This WAV is too long: " + frames + " samples (" + secs + " s at " +
      fmt.rate + " Hz). The analyzer accepts at most " + limits.maxSamples +
      " samples (" + maxSecs + " s at this rate).");
  }

  const samples = new Int16Array(frames);
  if (fmt.channels === 1) {
    for (let i = 0; i < frames; i++) {
      samples[i] = view.getInt16(dataOff + i * 2, true);
    }
  } else {
    for (let i = 0; i < frames; i++) {
      const l = view.getInt16(dataOff + i * 4, true);
      const r = view.getInt16(dataOff + i * 4 + 2, true);
      let m = Math.round((l + r) / 2);
      if (m > 32767) m = 32767;
      if (m < -32768) m = -32768;
      samples[i] = m;
    }
  }
  return {
    ok: true,
    rate: fmt.rate,
    channels: fmt.channels,
    frames,
    samples,
    mixed: fmt.channels === 2
  };
}

function wavError(error) {
  return { ok: false, error };
}

function wavAscii(view, off, n) {
  let s = "";
  for (let i = 0; i < n; i++) s += String.fromCharCode(view.getUint8(off + i));
  return s;
}
// PAGE-END

function writeAscii(view, off, s) {
  for (let i = 0; i < s.length; i++) view.setUint8(off + i, s.charCodeAt(i));
}

export function encodeWav({ format, channels, rate, bits, align, data }) {
  const dataSize = data.length;
  const buf = new ArrayBuffer(44 + dataSize);
  const v = new DataView(buf);
  writeAscii(v, 0, "RIFF");
  v.setUint32(4, 36 + dataSize, true);
  writeAscii(v, 8, "WAVE");
  writeAscii(v, 12, "fmt ");
  v.setUint32(16, 16, true);
  v.setUint16(20, format, true);
  v.setUint16(22, channels, true);
  v.setUint32(24, rate, true);
  v.setUint32(28, rate * align, true);
  v.setUint16(32, align, true);
  v.setUint16(34, bits, true);
  writeAscii(v, 36, "data");
  v.setUint32(40, dataSize, true);
  new Uint8Array(buf, 44).set(data);
  return buf;
}

export function encodeWavPcm16(rate, channels, samples) {
  const data = new Uint8Array(samples.length * 2);
  const view = new DataView(data.buffer);
  for (let i = 0; i < samples.length; i++) view.setInt16(i * 2, samples[i], true);
  return encodeWav({
    format: 1,
    channels,
    rate,
    bits: 16,
    align: channels * 2,
    data
  });
}
