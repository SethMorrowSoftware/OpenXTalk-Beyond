// Beyond Beats: the audio core.
//
// Copyright (C) 2026 OXT-Beyond contributors. GPL v3, as OXT-Beyond.
//
// The stack (beyond-beats-stack.livecodescript) owns the song and the
// screen; this file owns the sound and the clock. The builder
// (beyond-beats.livecodescript) keeps it in the stack as the custom
// property cAudioCore, and the stack runs it once a page with
// do ... as "JavaScript". It makes window.beyondBeats and never calls
// back into the stack: the stack tells it the song with set(), and asks
// it where the playhead is and how loud each channel is with poll().
//
// The sounds: a kit of sixteen made here, sample by sample, from
// oscillators and seeded noise (no sound files, so nothing to license,
// and the same sounds in every browser); five synths, played live from
// oscillators, a filter and two envelopes; and up to eight samples of
// the user's own (loadSample). A sample plays at its own pitch for C4
// (MIDI 60) and higher or lower for other notes; a synth plays each note
// for as long as it is held.
//
// Timing is the browser's audio clock's: a timer books each step about
// a tenth of a second ahead, so a slow frame of the engine never makes
// the beat stumble. Swing moves every second sixteenth later by up to
// half a step (0 is straight; 100 puts the off-step three quarters of
// the way through its pair, an MPC's 75%).
//
// The mixer: each channel goes through a low-pass filter, its fader
// (volume, mute and solo), a panner and a meter, and sends what comes out
// to a reverb and a delay; the channels, the reverb and the delay meet in
// the master, its volume, a limiter, a soft clip and a meter.
//
// The song, as set() takes it (every number is checked, cleanSong):
//   {bpm: 40..240, swing: 0..100, mode: "pattern" | "song",
//    cur: the pattern played in pattern mode (from 0),
//    from: the step a song starts at (from 0),
//    master: [volume 0..100, reverb 0 room | 1 hall, delay 2..4 steps,
//             feedback 0..90],
//    ch: [[sound, volume 0..100, pan -100..100, mute 0|1, solo 0|1,
//          filter 0..100, reverb send 0..100, delay send 0..100,
//          tune -24..24], ...],
//    pats: [{steps: 1..64,
//            rows: ["0907...", ...],    one string a channel, one digit a
//                                       step: 0 off, 1..9 its velocity
//            notes: [[[start, length, pitch, velocity], ...], ...]}, ...],
//                                       a list a channel, steps from 0
//    song: [[bar, pattern], ...]}      where each pattern starts, from 0
// A channel is heard when it is not muted and, if any channel is soloed,
// it is soloed too. The first phase's shape, {bpm, swing, steps, ch,
// rows}, is still taken: it is one pattern.
//
// The file ends in an expression, so do ... as "JavaScript" answers
// "ok" when the page can make sound and "none" when it cannot.

(function () {
  var w = window;
  if (w.beyondBeats) return;

  var KIT = ['Kick', 'Boom', 'Snare', 'Rim', 'Clap', 'Closed hat', 'Open hat', 'Crash',
             'Ride', 'Low tom', 'High tom', 'Shaker', 'Cowbell', 'Clave', 'Snap', 'Bass'];
  var SYNTHS = ['Saw lead', 'Square bass', 'Soft pad', 'Pluck', 'Keys'];
  var USER_SLOTS = 8;
  var FIRST_SYNTH = KIT.length, FIRST_USER = KIT.length + SYNTHS.length;
  var SOUNDS = FIRST_USER + USER_SLOTS;
  var LOOKAHEAD = 0.12;   // seconds booked ahead of the clock
  var TICK = 25;          // milliseconds between bookings
  var Ctx = w.AudioContext || w.webkitAudioContext;
  var Offline = w.OfflineAudioContext || w.webkitOfflineAudioContext;

  // ---- the kit, made sample by sample -----------------------------------

  // A small seeded random number generator (mulberry32): the noise of a
  // snare is the same noise every time.
  function rng(seed) {
    return function () {
      seed |= 0; seed = seed + 0x6D2B79F5 | 0;
      var t = Math.imul(seed ^ seed >>> 15, 1 | seed);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }

  // A biquad filter (the Audio EQ Cookbook's), run over a whole array.
  function biquad(x, rate, kind, freq, q) {
    var w0 = 2 * Math.PI * freq / rate, cs = Math.cos(w0), al = Math.sin(w0) / (2 * q);
    var b0, b1, b2, a0 = 1 + al, a1 = -2 * cs, a2 = 1 - al;
    if (kind === 'lowpass') { b0 = (1 - cs) / 2; b1 = 1 - cs; b2 = b0; }
    else if (kind === 'highpass') { b0 = (1 + cs) / 2; b1 = -(1 + cs); b2 = b0; }
    else { b0 = al; b1 = 0; b2 = -al; }      // bandpass, peak gain 0 dB
    var y = new Float32Array(x.length), x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (var i = 0; i < x.length; i++) {
      var v = (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
      x2 = x1; x1 = x[i]; y2 = y1; y1 = v; y[i] = v;
    }
    return y;
  }

  // An envelope: a 1 ms rise, then an exponential fall that reaches about
  // -60 dB after `decay` seconds.
  function env(t, decay) {
    var rise = t < 0.001 ? t / 0.001 : 1;
    return rise * Math.exp(-6.9 * t / decay);
  }

  function noise(n, seed) {
    var r = rng(seed), x = new Float32Array(n);
    for (var i = 0; i < n; i++) x[i] = r() * 2 - 1;
    return x;
  }

  // A tone whose pitch falls from f1 to f2 (tau: how fast), in a wave of
  // the given shape.
  function tone(n, rate, f1, f2, tau, shape) {
    var x = new Float32Array(n), ph = 0;
    for (var i = 0; i < n; i++) {
      var t = i / rate, f = f2 + (f1 - f2) * Math.exp(-t / tau);
      ph += f / rate; ph -= Math.floor(ph);
      if (shape === 'square') x[i] = ph < 0.5 ? 1 : -1;
      else if (shape === 'saw') x[i] = 2 * ph - 1;
      else if (shape === 'triangle') x[i] = 1 - 4 * Math.abs(ph - 0.5);
      else x[i] = Math.sin(2 * Math.PI * ph);
    }
    return x;
  }

  function shaped(x, rate, decay, delay) {
    var d = delay || 0;
    for (var i = 0; i < x.length; i++) {
      var t = i / rate - d;
      x[i] *= t < 0 ? 0 : env(t, decay);
    }
    return x;
  }

  function mix(parts, n) {
    var y = new Float32Array(n);
    for (var p = 0; p < parts.length; p++) {
      var x = parts[p][0], a = parts[p][1];
      for (var i = 0; i < n; i++) y[i] += a * x[i];
    }
    return y;
  }

  // Each sound of the kit: [length in seconds, maker(n, rate)].
  var MAKERS = [
    // Kick: a sine that falls from 150 to 45 Hz, and a click on top
    [0.5, function (n, r) {
      return mix([[shaped(tone(n, r, 150, 45, 0.03), r, 0.42), 1],
                  [shaped(biquad(noise(n, 1), r, 'highpass', 3000, 0.7), r, 0.006), 0.35]], n);
    }],
    // Boom: a long, round low sine, a little overdriven
    [1.2, function (n, r) {
      var x = shaped(tone(n, r, 70, 44, 0.06), r, 1.1);
      for (var i = 0; i < n; i++) x[i] = Math.tanh(1.8 * x[i]);
      return x;
    }],
    // Snare: bright noise and a short triangle body
    [0.35, function (n, r) {
      return mix([[shaped(biquad(noise(n, 2), r, 'highpass', 1400, 0.7), r, 0.2), 0.9],
                  [shaped(tone(n, r, 210, 175, 0.02, 'triangle'), r, 0.09), 0.6]], n);
    }],
    // Rim: a click of a high sine and a little band of noise
    [0.12, function (n, r) {
      return mix([[shaped(tone(n, r, 1750, 1650, 0.01), r, 0.03), 0.8],
                  [shaped(biquad(noise(n, 3), r, 'bandpass', 3200, 2), r, 0.025), 0.9]], n);
    }],
    // Clap: three quick bursts and a tail, in a band of noise
    [0.4, function (n, r) {
      var b = biquad(noise(n, 4), r, 'bandpass', 1300, 1.4), y = new Float32Array(n);
      for (var i = 0; i < n; i++) {
        var t = i / r, a = 0;
        for (var k = 0; k < 3; k++) { var s = t - k * 0.011; if (s >= 0) a = Math.max(a, env(s, 0.03)); }
        if (t >= 0.033) a = Math.max(a, env(t - 0.033, 0.22) * 0.85);
        y[i] = b[i] * a;
      }
      return y;
    }],
    // Closed hat: very high noise, very short
    [0.12, function (n, r) {
      return shaped(biquad(noise(n, 5), r, 'highpass', 7500, 0.8), r, 0.05);
    }],
    // Open hat: the same, held longer
    [0.6, function (n, r) {
      return shaped(biquad(noise(n, 6), r, 'highpass', 7000, 0.8), r, 0.45);
    }],
    // Crash: a wash of high noise
    [1.8, function (n, r) {
      return mix([[shaped(biquad(noise(n, 7), r, 'highpass', 4500, 0.6), r, 1.6), 0.9],
                  [shaped(biquad(noise(n, 8), r, 'bandpass', 9000, 1), r, 0.9), 0.5]], n);
    }],
    // Ride: metal, from square waves at pitches that are not in tune
    [1.2, function (n, r) {
      var f = [313, 487, 587, 803, 1047, 1229], parts = [];
      for (var k = 0; k < f.length; k++) parts.push([tone(n, r, f[k], f[k], 1, 'square'), 1 / f.length]);
      return shaped(biquad(mix(parts, n), r, 'highpass', 5000, 0.7), r, 1.0);
    }],
    // Low tom
    [0.6, function (n, r) { return shaped(tone(n, r, 145, 92, 0.12), r, 0.5); }],
    // High tom
    [0.45, function (n, r) { return shaped(tone(n, r, 265, 175, 0.1), r, 0.38); }],
    // Shaker: a soft rise of a band of high noise
    [0.15, function (n, r) {
      var x = biquad(noise(n, 9), r, 'bandpass', 6500, 1.2);
      for (var i = 0; i < n; i++) { var t = i / r; x[i] *= Math.min(1, t / 0.012) * Math.exp(-6.9 * Math.max(0, t - 0.012) / 0.1); }
      return x;
    }],
    // Cowbell: two square waves through a band
    [0.4, function (n, r) {
      return shaped(biquad(mix([[tone(n, r, 545, 545, 1, 'square'), 0.5],
                                [tone(n, r, 815, 815, 1, 'square'), 0.5]], n), r, 'bandpass', 900, 1.5), r, 0.3);
    }],
    // Clave: a short, high sine
    [0.12, function (n, r) { return shaped(tone(n, r, 2500, 2500, 1), r, 0.06); }],
    // Snap: a crack of noise
    [0.15, function (n, r) {
      return shaped(biquad(noise(n, 10), r, 'bandpass', 2400, 1.1), r, 0.07);
    }],
    // Bass: a saw at A1 (55 Hz) through a falling low-pass
    [0.7, function (n, r) {
      var x = tone(n, r, 55, 55, 1, 'saw'), y = new Float32Array(n), lp = 0;
      for (var i = 0; i < n; i++) {
        var t = i / r, cut = 120 + 1600 * Math.exp(-t / 0.08), a = 1 - Math.exp(-2 * Math.PI * cut / r);
        lp += a * (x[i] - lp); y[i] = lp;
      }
      return shaped(y, r, 0.6);
    }]
  ];

  // One sound of the kit at a sample rate, its loudest sample at 0.9.
  function makeSound(index, rate) {
    var m = MAKERS[index], n = Math.round(m[0] * rate), x = m[1](n, rate), peak = 0;
    for (var i = 0; i < n; i++) peak = Math.max(peak, Math.abs(x[i]));
    if (peak > 0) for (var j = 0; j < n; j++) x[j] *= 0.9 / peak;
    // the last 5 ms fade out, so a sound never ends in a click
    var f = Math.min(n, Math.round(0.005 * rate));
    for (var k = 0; k < f; k++) x[n - 1 - k] *= k / f;
    return x;
  }

  function kitFor(ctx) {
    var buffers = [];
    for (var i = 0; i < MAKERS.length; i++) {
      var data = makeSound(i, ctx.sampleRate), b = ctx.createBuffer(1, data.length, ctx.sampleRate);
      b.getChannelData(0).set(data);
      buffers.push(b);
    }
    return buffers;
  }

  // ---- the synths -------------------------------------------------------

  // Each synth: its oscillators ([wave, octave in semitones, detune in
  // cents, level]), a low-pass filter (cut-off in Hz, how far its
  // envelope opens it, how fast that closes, resonance), an envelope
  // (attack, decay, sustain level, release, in seconds) and the note a
  // step plays (a note of the piano roll plays its own).
  var PRESETS = [
    {osc: [['sawtooth', 0, -7, 0.5], ['sawtooth', 0, 7, 0.5]], cut: 1800, env: 2600, fdecay: 0.3, q: 4,
     a: 0.005, d: 0.25, s: 0.7, r: 0.15, base: 60, level: 0.55},
    {osc: [['square', 0, 0, 0.5], ['sine', 0, 0, 0.7]], cut: 380, env: 1500, fdecay: 0.12, q: 6,
     a: 0.003, d: 0.18, s: 0.6, r: 0.08, base: 36, level: 0.8},
    {osc: [['sawtooth', 0, -12, 0.35], ['sawtooth', 0, 12, 0.35], ['triangle', 12, 0, 0.3]], cut: 1100, env: 500,
     fdecay: 0.8, q: 1, a: 0.35, d: 0.6, s: 0.8, r: 0.6, base: 60, level: 0.45},
    {osc: [['triangle', 0, 0, 0.6], ['sawtooth', 0, 4, 0.4]], cut: 450, env: 4200, fdecay: 0.12, q: 3,
     a: 0.002, d: 0.35, s: 0, r: 0.12, base: 60, level: 0.7},
    {osc: [['sine', 0, 0, 0.75], ['triangle', 12, 0, 0.25]], cut: 5000, env: 2000, fdecay: 0.4, q: 0.7,
     a: 0.003, d: 0.9, s: 0.3, r: 0.25, base: 60, level: 0.7}
  ];

  function hz(midi) { return 440 * Math.pow(2, (midi - 69) / 12); }

  // The level of an attack-decay-sustain envelope `t` seconds in.
  function adsAt(P, t) {
    if (t <= P.a) return P.level * t / P.a;
    return P.level * (P.s + (1 - P.s) * Math.exp(-3 * (t - P.a) / P.d));
  }

  // One synth note into `out`: it sounds from `when` for `dur` seconds,
  // then its release.
  function synth(ctx, P, midi, when, dur, out) {
    var f = hz(midi), amp = ctx.createGain(), filt = ctx.createBiquadFilter();
    var hold = Math.max(dur, 0.01), end = when + hold, stop = end + P.r + 0.05;
    filt.type = 'lowpass';
    filt.Q.value = P.q;
    filt.frequency.setValueAtTime(Math.min(18000, P.cut + P.env), when);
    filt.frequency.setTargetAtTime(P.cut, when, P.fdecay / 3);
    amp.gain.setValueAtTime(0, when);
    if (hold <= P.a) {
      // let go before the attack is over: the release starts from where
      // the attack had got to
      amp.gain.linearRampToValueAtTime(adsAt(P, hold), end);
    } else {
      amp.gain.linearRampToValueAtTime(P.level, when + P.a);
      amp.gain.setTargetAtTime(P.level * P.s, when + P.a, P.d / 3);
      amp.gain.setValueAtTime(adsAt(P, hold), end);
    }
    amp.gain.linearRampToValueAtTime(0, end + P.r);
    filt.connect(amp);
    amp.connect(out);
    for (var k = 0; k < P.osc.length; k++) {
      var o = P.osc[k], x = ctx.createOscillator(), g = ctx.createGain();
      x.type = o[0];
      x.frequency.value = f * Math.pow(2, o[1] / 12);
      x.detune.value = o[2];
      g.gain.value = o[3];
      x.connect(g);
      g.connect(filt);
      x.start(when);
      x.stop(stop);
    }
  }

  // ---- the song ------------------------------------------------------

  function clamp(v, lo, hi, dflt) {
    v = Number(v);
    if (!isFinite(v)) return dflt;
    return Math.max(lo, Math.min(hi, v));
  }

  function int(v, lo, hi, dflt) { return Math.round(clamp(v, lo, hi, dflt)); }

  // A slot of the user's samples, from 1, as an index from 0; -1 when it
  // is not one.
  function slotOf(v) {
    v = Number(v);
    return v >= 1 && v <= USER_SLOTS && v === Math.floor(v) ? v - 1 : -1;
  }

  // The song as set() was given it, made safe: numbers in their ranges,
  // rows of digits as long as their pattern, notes inside it.
  function cleanSong(s) {
    s = s || {};
    var song = {bpm: clamp(s.bpm, 40, 240, 120), swing: clamp(s.swing, 0, 100, 0),
                mode: s.mode === 'song' ? 'song' : 'pattern', ch: [], pats: [], song: []};
    var m = s.master || [];
    song.master = [clamp(m[0], 0, 100, 80), m[1] ? 1 : 0, int(m[2], 2, 4, 3), clamp(m[3], 0, 90, 35)];
    var ch = s.ch || [];
    for (var i = 0; i < ch.length; i++) {
      var c = ch[i] || [];
      song.ch.push([int(c[0], 0, SOUNDS - 1, 0), clamp(c[1], 0, 100, 78), clamp(c[2], -100, 100, 0),
                    c[3] ? 1 : 0, c[4] ? 1 : 0, clamp(c[5], 0, 100, 100), clamp(c[6], 0, 100, 0),
                    clamp(c[7], 0, 100, 0), int(c[8], -24, 24, 0)]);
    }
    var pats = s.pats || [{steps: s.steps, rows: s.rows}];
    for (var p = 0; p < pats.length; p++) {
      var src = pats[p] || {}, pat = {steps: int(src.steps, 1, 64, 16), rows: [], notes: []};
      for (var r = 0; r < song.ch.length; r++) {
        var row = String((src.rows || [])[r] || '').replace(/[^0-9]/g, '0');
        while (row.length < pat.steps) row += '0';
        pat.rows.push(row.slice(0, pat.steps));
        var notes = ((src.notes || [])[r]) || [], list = [];
        for (var n = 0; n < notes.length && list.length < 64; n++) {
          var x = notes[n] || [], start = int(x[0], 0, 63, -1);
          if (start < 0 || start >= pat.steps) continue;
          list.push([start, int(x[1], 1, pat.steps - start, 1), int(x[2], 0, 127, 60), int(x[3], 1, 9, 7)]);
        }
        pat.notes.push(list);
      }
      song.pats.push(pat);
    }
    if (!song.pats.length) song.pats.push({steps: 16, rows: [], notes: []});
    song.cur = int(s.cur, 0, song.pats.length - 1, 0);
    var arr = s.song || [];
    for (var k = 0; k < arr.length; k++) {
      var a = arr[k] || [], bar = int(a[0], 0, 255, -1), pp = int(a[1], 0, song.pats.length - 1, -1);
      if (Number(a[0]) === bar && Number(a[1]) === pp) song.song.push([bar, pp]);
    }
    song.from = int(s.from, 0, 4095, 0);
    // the first phase's names for the pattern played
    song.steps = song.pats[song.cur].steps;
    song.rows = song.pats[song.cur].rows;
    return song;
  }

  function audible(song, i) {
    var anySolo = false;
    for (var k = 0; k < song.ch.length; k++) if (song.ch[k][4]) anySolo = true;
    return !song.ch[i][3] && (!anySolo || !!song.ch[i][4]);
  }

  function stepLength(song) { return 60 / song.bpm / 4; }

  // How much later than the grid step `step` sounds: every second
  // sixteenth, by swing/100 of half a step.
  function swingDelay(song, step) {
    return step % 2 === 1 ? song.swing / 100 * stepLength(song) / 2 : 0;
  }

  // What plays at each step: in pattern mode the pattern's own steps; in
  // song mode the song from its first bar to the end of its last
  // pattern, each step a list of [pattern, its step].
  function timeline(song) {
    var at = [], k;
    if (song.mode !== 'song') {
      var cur = song.pats[song.cur];
      for (k = 0; k < cur.steps; k++) at.push([[song.cur, k]]);
      return at;
    }
    var length = 16;
    for (k = 0; k < song.song.length; k++) {
      var c = song.song[k];
      length = Math.max(length, c[0] * 16 + song.pats[c[1]].steps);
    }
    length = Math.ceil(length / 16) * 16;
    for (k = 0; k < length; k++) at.push([]);
    for (k = 0; k < song.song.length; k++) {
      var bar = song.song[k][0], p = song.song[k][1], steps = song.pats[p].steps;
      for (var s = 0; s < steps; s++) at[bar * 16 + s].push([p, s]);
    }
    return at;
  }

  // ---- the mixer -------------------------------------------------------

  function volumeGain(v) { var a = v / 100; return a * a; }

  // A filter at 100 is open (20 kHz); at 0, 80 Hz.
  function cutoff(v) { return 80 * Math.pow(250, v / 100); }

  // The soft clip's curve, over an input halved first (so it reaches from
  // -2 to 2): straight up to 0.8, then bending to 0.99 at most.
  function softClip() {
    var n = 4097, c = new Float32Array(n);
    for (var i = 0; i < n; i++) {
      var x = 4 * i / (n - 1) - 2, a = Math.abs(x);
      c[i] = a < 0.8 ? x : (x < 0 ? -1 : 1) * (0.8 + 0.19 * Math.tanh((a - 0.8) / 0.19));
    }
    return c;
  }

  // The reverb's echo of a clap in a room (1.2 s) or a hall (2.8 s):
  // stereo noise that dies away, the same every time. It is scaled here,
  // not by the browser (normalize is off), so that it is the same in
  // every browser: a long, steady sound sent to it at 100 comes back
  // about as loud as it went in.
  function impulse(ctx, hall) {
    var seconds = hall ? 2.8 : 1.2, n = Math.round(seconds * ctx.sampleRate);
    var b = ctx.createBuffer(2, n, ctx.sampleRate);
    for (var c = 0; c < 2; c++) {
      var d = b.getChannelData(c), r = rng(hall ? 101 + c : 201 + c), power = 0;
      for (var i = 0; i < n; i++) {
        d[i] = (r() * 2 - 1) * Math.pow(1 - i / n, hall ? 2.2 : 3);
        power += d[i] * d[i];
      }
      var scale = Math.sqrt(0.7 / power);
      for (var j = 0; j < n; j++) d[j] *= scale;
    }
    return b;
  }

  function makeMixer(ctx, raw) {
    var m = {ctx: ctx, kit: kitFor(ctx), strips: [], master: ctx.createGain(), size: -1};
    m.meter = ctx.createAnalyser();
    m.meter.fftSize = 512;
    if (raw) {
      m.master.connect(m.meter);
    } else {
      // a limiter, so that many loud channels never clip: a compressor
      // that holds the level down, and after it a soft clip for what its
      // attack lets through, which never passes 0.99
      var lim = ctx.createDynamicsCompressor();
      lim.threshold.value = -3; lim.knee.value = 0; lim.ratio.value = 20;
      lim.attack.value = 0.002; lim.release.value = 0.1;
      var half = ctx.createGain(), clip = ctx.createWaveShaper();
      half.gain.value = 0.5;
      clip.curve = softClip();
      m.master.connect(lim); lim.connect(half); half.connect(clip); clip.connect(m.meter);
    }
    m.meter.connect(ctx.destination);
    // the reverb and the delay, each fed by the channels' sends
    m.revIn = ctx.createGain();
    m.reverb = ctx.createConvolver();
    m.reverb.normalize = false;
    m.revIn.connect(m.reverb); m.reverb.connect(m.master);
    m.dlyIn = ctx.createGain();
    m.delay = ctx.createDelay(4);
    m.fb = ctx.createGain();
    var dark = ctx.createBiquadFilter();
    dark.type = 'lowpass'; dark.frequency.value = 3500;
    m.dlyIn.connect(m.delay); m.delay.connect(dark); dark.connect(m.fb); m.fb.connect(m.delay);
    m.delay.connect(m.master);
    // (a browser may add one block, 128 samples, to every echo after the
    // first: the loop is one block late)
    return m;
  }

  function strip(m, i) {
    while (m.strips.length <= i) {
      var ctx = m.ctx, s = {input: ctx.createGain(), filter: ctx.createBiquadFilter(), fader: ctx.createGain(),
                            pan: ctx.createStereoPanner ? ctx.createStereoPanner() : null,
                            meter: ctx.createAnalyser(), rev: ctx.createGain(), dly: ctx.createGain()};
      s.filter.type = 'lowpass';
      s.filter.frequency.value = ctx.sampleRate / 2;
      s.filter.Q.value = 0;
      s.meter.fftSize = 512;
      s.input.connect(s.filter); s.filter.connect(s.fader);
      var out = s.fader;
      if (s.pan) { s.fader.connect(s.pan); out = s.pan; }
      out.connect(s.meter); s.meter.connect(m.master);
      out.connect(s.rev); s.rev.connect(m.revIn);
      out.connect(s.dly); s.dly.connect(m.dlyIn);
      s.rev.gain.value = 0; s.dly.gain.value = 0;
      m.strips.push(s);
    }
    return m.strips[i];
  }

  // Every setting of the song on the mixer, from `when`: mute and solo are
  // gains too, so a change is heard at once, even on a note that sounds.
  function applyMix(m, song, when) {
    for (var i = 0; i < song.ch.length; i++) {
      var s = strip(m, i), c = song.ch[i];
      s.fader.gain.setValueAtTime(audible(song, i) ? volumeGain(c[1]) : 0, when);
      if (s.pan) s.pan.pan.setValueAtTime(c[2] / 100, when);
      // at 100 the filter stands at the top of the band, where it lets
      // everything through as it is
      s.filter.frequency.setValueAtTime(c[5] >= 100 ? m.ctx.sampleRate / 2 : cutoff(c[5]), when);
      s.rev.gain.setValueAtTime(c[6] / 100, when);
      s.dly.gain.setValueAtTime(c[7] / 100, when);
    }
    for (var k = song.ch.length; k < m.strips.length; k++) m.strips[k].fader.gain.setValueAtTime(0, when);
    var master = song.master;
    m.master.gain.setValueAtTime(volumeGain(master[0]) * 1.25, when);
    if (m.size !== master[1]) { m.size = master[1]; m.reverb.buffer = impulse(m.ctx, master[1]); }
    m.delay.delayTime.setValueAtTime(master[2] * stepLength(song), when);
    m.fb.gain.setValueAtTime(master[3] / 100, when);
  }

  // One sound of channel i: a sample (at its pitch for C4, MIDI 60) or a
  // synth note held for `dur` seconds. `pitch` is null for a step: then a
  // sample plays as it is and a synth plays its own note.
  function voice(m, song, i, pitch, vel, when, dur, user, direct) {
    var ctx = m.ctx, c = song.ch[i], sound = c[0], g = ctx.createGain();
    g.gain.value = vel / 9;
    g.connect(direct || strip(m, i).input);
    if (sound >= FIRST_SYNTH && sound < FIRST_USER) {
      var P = PRESETS[sound - FIRST_SYNTH];
      synth(ctx, P, (pitch === null ? P.base : pitch) + c[8], when, dur, g);
      return true;
    }
    var buf = sound < FIRST_SYNTH ? m.kit[sound] : (user || [])[sound - FIRST_USER];
    if (!buf || buf === 'wait') return false;
    var src = ctx.createBufferSource();
    src.buffer = buf;
    src.playbackRate.value = Math.pow(2, ((pitch === null ? 60 : pitch) - 60 + c[8]) / 12);
    src.connect(g);
    src.start(when);
    return true;
  }

  // Every sound of one step of the timeline, at `when`.
  function playStep(m, song, entries, step, when, user, log) {
    var len = stepLength(song);
    for (var e = 0; e < entries.length; e++) {
      var pat = song.pats[entries[e][0]], s = entries[e][1];
      for (var i = 0; i < song.ch.length; i++) {
        if (!audible(song, i)) continue;
        var vel = pat.rows[i].charCodeAt(s) - 48;
        if (vel > 0 && vel <= 9 && voice(m, song, i, null, vel, when, len, user) && log) log.push([i, step, when, null]);
        var notes = pat.notes[i];
        for (var n = 0; n < notes.length; n++) {
          var x = notes[n];
          if (x[0] === s && voice(m, song, i, x[2], x[3], when, x[1] * len, user) && log) log.push([i, step, when, x[2]]);
        }
      }
    }
  }

  // ---- WAV files -------------------------------------------------------

  // Two channels of samples as a 16-bit WAV file.
  function wav(left, right, rate) {
    var n = left.length, buf = new ArrayBuffer(44 + n * 4), v = new DataView(buf), o = 0;
    function str(t) { for (var i = 0; i < t.length; i++) v.setUint8(o++, t.charCodeAt(i)); }
    function u32(x) { v.setUint32(o, x, true); o += 4; }
    function u16(x) { v.setUint16(o, x, true); o += 2; }
    str('RIFF'); u32(36 + n * 4); str('WAVE'); str('fmt '); u32(16); u16(1); u16(2); u32(rate); u32(rate * 4); u16(4);
    u16(16); str('data'); u32(n * 4);
    for (var i = 0; i < n; i++) {
      v.setInt16(o, Math.max(-1, Math.min(1, left[i])) * 32767, true); o += 2;
      v.setInt16(o, Math.max(-1, Math.min(1, right[i])) * 32767, true); o += 2;
    }
    return buf;
  }

  function fromBase64(text) {
    var s = atob(String(text).replace(/[^A-Za-z0-9+\/=]/g, '')), u = new Uint8Array(s.length);
    for (var i = 0; i < s.length; i++) u[i] = s.charCodeAt(i);
    return u.buffer;
  }

  // ---- the live studio --------------------------------------------------

  var B = w.beyondBeats = {
    kit: KIT, synths: SYNTHS, userSlots: USER_SLOTS,
    ctx: null, mixer: null, song: cleanSong({}), at: null, user: [],
    playing: false, step: 0, next: 0, queue: [], shown: -1, log: null,
    exporting: '', lastExport: null,

    // The page can make sound only after a click or a key: the context is
    // made, or woken, by the first one (the stack's clicks reach the page
    // as the canvas's, so this hears them too).
    unlock: function () {
      if (!Ctx) return;
      if (!B.ctx) {
        try { B.ctx = new Ctx(); } catch (e) { return; }
        B.mixer = makeMixer(B.ctx, false);
        applyMix(B.mixer, B.song, 0);
      }
      if (B.ctx.state === 'suspended' && B.ctx.resume) B.ctx.resume();
    },

    // "running", "suspended" (waiting for a click), or "none"
    state: function () { return B.ctx ? B.ctx.state : (Ctx ? 'suspended' : 'none'); },

    set: function (s) {
      B.song = cleanSong(typeof s === 'string' ? JSON.parse(s) : s);
      B.at = timeline(B.song);
      if (B.step >= B.at.length) B.step = 0;
      if (B.mixer) applyMix(B.mixer, B.song, B.ctx.currentTime);
      return 'ok';
    },

    // Plays from the start of the pattern, or from the song's `from` step.
    start: function () {
      B.unlock();
      if (!B.ctx) return 'none';
      if (!B.at) B.at = timeline(B.song);
      B.playing = true; B.queue = []; B.shown = -1;
      B.step = B.song.mode === 'song' ? Math.min(B.song.from, B.at.length - 1) : 0;
      B.next = B.ctx.currentTime + 0.06;
      B.book();
      return 'ok';
    },

    stop: function () { B.playing = false; B.queue = []; B.shown = -1; return 'ok'; },

    // The step sounding now (counted from 0: of the pattern, or of the
    // song), or -1 when stopped.
    now: function () {
      if (!B.playing || !B.ctx) return -1;
      var t = B.ctx.currentTime;
      while (B.queue.length && B.queue[0][1] <= t) B.shown = B.queue.shift()[0];
      return B.shown;
    },

    // How loud each channel and the master are now, 0..100 (a meter's
    // scale: 48 dB of it).
    levels: function () {
      var out = [], m = B.mixer, data = new Float32Array(512);
      function level(an) {
        an.getFloatTimeDomainData(data);
        var p = 0;
        for (var i = 0; i < data.length; i++) p = Math.max(p, Math.abs(data[i]));
        return p <= 0 ? 0 : Math.max(0, Math.min(100, Math.round((20 * Math.log(p) / Math.LN10 + 48) / 48 * 100)));
      }
      for (var i = 0; i < B.song.ch.length; i++) out.push(m && m.strips[i] ? level(m.strips[i].meter) : 0);
      out.push(m ? level(m.meter) : 0);
      return out;
    },

    // What the stack asks many times a second: "step|level,level,...".
    poll: function () { return B.now() + '|' + B.levels().join(','); },

    // One channel's sound now, at a velocity and a pitch (null or
    // nothing: as a step plays it): a pad clicked, a key of the piano
    // roll, a sound tried. Heard even when the channel is muted.
    hit: function (channel, velocity, pitch) {
      B.unlock();
      if (!B.ctx || channel < 0 || channel >= B.song.ch.length) return 'none';
      var ctx = B.ctx, c = B.song.ch[channel], g = ctx.createGain(), p = ctx.createStereoPanner ? ctx.createStereoPanner() : null;
      g.gain.value = volumeGain(c[1]);
      if (p) { p.pan.value = c[2] / 100; g.connect(p); p.connect(B.mixer.master); } else g.connect(B.mixer.master);
      var ok = voice(B.mixer, B.song, channel, pitch === undefined || pitch === null || pitch === '' ? null : Number(pitch),
                     velocity || 7, ctx.currentTime + 0.005, 0.3, B.user, g);
      return ok ? 'ok' : 'none';
    },

    // Books every step that starts before the clock is LOOKAHEAD ahead.
    book: function () {
      if (!B.playing || !B.ctx) return;
      var ahead = B.ctx.currentTime + LOOKAHEAD, song = B.song, at = B.at;
      while (B.next < ahead) {
        var when = B.next + swingDelay(song, B.step);
        playStep(B.mixer, song, at[B.step], B.step, when, B.user, B.log);
        B.queue.push([B.step, when]);
        B.next += stepLength(song);
        B.step = (B.step + 1) % at.length;
      }
    },

    // A sample of the user's own, as the base64 of its file (WAV, MP3,
    // OGG...), into a slot from 1: decoded by the browser, which takes a
    // moment (sampleState says when).
    loadSample: function (slot, data) {
      slot = slotOf(slot);
      if (slot < 0) return 'none';
      B.user[slot] = 'wait';
      var ctx = B.ctx || (Offline ? new Offline(1, 1, 44100) : null);
      if (!ctx) { B.user[slot] = null; return 'none'; }
      var done = function (b) { B.user[slot] = b; }, fail = function () { B.user[slot] = null; };
      try {
        var p = ctx.decodeAudioData(fromBase64(data), done, fail);
        if (p && p.catch) p.catch(fail);
      } catch (e) { fail(); }
      return 'ok';
    },

    // "ready", "wait", "error", or "" for a slot with nothing in it.
    sampleState: function (slot) {
      var b = B.user[slotOf(slot)];
      return b === undefined ? '' : b === 'wait' ? 'wait' : b ? 'ready' : 'error';
    },

    clearSample: function (slot) {
      slot = slotOf(slot);
      if (slot < 0) return 'none';
      B.user[slot] = undefined;
      return 'ok';
    },

    // The song (or the pattern), rendered faster than real time: `loops`
    // times through, then `tail` seconds for the reverb and the delay to
    // ring out (1 by default). Resolves to {rate, left, right, log,
    // seconds}. raw leaves out the master's limiter (the check measures
    // levels with it out).
    render: function (s, loops, rate, raw, tail) {
      if (!Offline) return Promise.reject(new Error('no OfflineAudioContext'));
      var song = cleanSong(s), at = timeline(song), n = Math.max(1, loops || 1) * at.length;
      var first = song.mode === 'song' ? Math.min(song.from, at.length - 1) : 0;
      var seconds = (n - first) * stepLength(song), r = rate || 44100;
      var ctx = new Offline(2, Math.ceil((seconds + (tail === undefined ? 1 : tail)) * r), r);
      var m = makeMixer(ctx, !!raw), log = [];
      applyMix(m, song, 0);
      for (var k = first; k < n; k++) {
        var step = k % at.length;
        playStep(m, song, at[step], step, (k - first) * stepLength(song) + swingDelay(song, step), B.user, log);
      }
      return ctx.startRendering().then(function (buf) {
        return {rate: r, left: buf.getChannelData(0), right: buf.getChannelData(1), log: log, seconds: seconds};
      });
    },

    // Renders the song as it is set (the song from its start, or the
    // pattern once) with two seconds of tail, and hands the browser a WAV
    // file of it to save as `name`. exportState says how it goes:
    // "working", "done" or "error: why".
    exportWav: function (name) {
      if (B.exporting === 'working') return 'busy';
      B.exporting = 'working';
      var song = JSON.parse(JSON.stringify(B.song));
      song.from = 0;
      B.render(song, 1, 44100, false, 2).then(function (r) {
        var data = wav(r.left, r.right, r.rate), blob = new Blob([data], {type: 'audio/wav'});
        B.lastExport = {bytes: data.byteLength, seconds: r.left.length / r.rate, name: String(name || 'beyond-beats.wav')};
        var a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = B.lastExport.name;
        document.body.appendChild(a);
        a.click();
        setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 60000);
        B.exporting = 'done';
      }, function (e) { B.exporting = 'error: ' + (e && e.message || e); });
      return 'ok';
    },

    exportState: function () { return B.exporting; },

    // for the check
    makeSound: makeSound, cleanSong: cleanSong, audible: audible, timeline: timeline,
    stepLength: stepLength, swingDelay: swingDelay, cutoff: cutoff, wav: wav
  };

  if (Ctx) {
    setInterval(B.book, TICK);
    ['pointerdown', 'mousedown', 'touchend', 'keydown'].forEach(function (e) {
      w.addEventListener(e, B.unlock, true);
    });
  }
})();
window.beyondBeats && (window.AudioContext || window.webkitAudioContext) ? 'ok' : 'none';
