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
// it where the playhead is with now().
//
// The kit is made here, sample by sample, from oscillators and seeded
// noise: there are no sound files, so nothing to license, and the same
// sounds come out on every browser (tools/ci/beyond_beats_check.py
// renders them and checks).
//
// Timing is the browser's audio clock's: a timer books each step about
// a tenth of a second ahead, so a slow frame of the engine never makes
// the beat stumble. Swing moves every second sixteenth later by up to
// half a step (0 is straight; 100 puts the off-step three quarters of
// the way through its pair, an MPC's 75%).
//
// The song, as set() takes it:
//   {bpm: 40..240, swing: 0..100, steps: 1..64,
//    ch: [[sound 0..15, volume 0..100, pan -100..100, mute 0|1, solo 0|1], ...],
//    rows: ["0907...", ...]}     one string a channel, one digit a step:
//                                0 is off, 1..9 the step's velocity
// A channel is heard when it is not muted and, if any channel is soloed,
// it is soloed too.
//
// The file ends in an expression, so do ... as "JavaScript" answers
// "ok" when the page can make sound and "none" when it cannot.

(function () {
  var w = window;
  if (w.beyondBeats) return;

  var KIT = ['Kick', 'Boom', 'Snare', 'Rim', 'Clap', 'Closed hat', 'Open hat', 'Crash',
             'Ride', 'Low tom', 'High tom', 'Shaker', 'Cowbell', 'Clave', 'Snap', 'Bass'];
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

  // ---- the song ------------------------------------------------------

  function clamp(v, lo, hi, dflt) {
    v = Number(v);
    if (!isFinite(v)) return dflt;
    return Math.max(lo, Math.min(hi, v));
  }

  // The song as set() was given it, made safe: numbers in their ranges,
  // rows of digits as long as the pattern.
  function cleanSong(s) {
    s = s || {};
    var song = {bpm: clamp(s.bpm, 40, 240, 120), swing: clamp(s.swing, 0, 100, 0),
                steps: Math.round(clamp(s.steps, 1, 64, 16)), ch: [], rows: []};
    var ch = s.ch || [], rows = s.rows || [];
    for (var i = 0; i < ch.length; i++) {
      var c = ch[i] || [];
      song.ch.push([Math.round(clamp(c[0], 0, MAKERS.length - 1, 0)), clamp(c[1], 0, 100, 78),
                    clamp(c[2], -100, 100, 0), c[3] ? 1 : 0, c[4] ? 1 : 0]);
      var row = String(rows[i] || '').replace(/[^0-9]/g, '0');
      while (row.length < song.steps) row += '0';
      song.rows.push(row.slice(0, song.steps));
    }
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

  // ---- the mixer: a gain and a panner a channel, then the master -------

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

  function volumeGain(v) { var a = v / 100; return a * a; }

  function makeMixer(ctx, raw) {
    var mixer = {ctx: ctx, kit: kitFor(ctx), strips: [], master: ctx.createGain()};
    mixer.master.gain.value = 0.8;
    if (raw) {
      mixer.master.connect(ctx.destination);
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
      mixer.master.connect(lim); lim.connect(half); half.connect(clip); clip.connect(ctx.destination);
    }
    return mixer;
  }

  function strip(mixer, i) {
    while (mixer.strips.length <= i) {
      var ctx = mixer.ctx, g = ctx.createGain(), p = ctx.createStereoPanner ? ctx.createStereoPanner() : null;
      if (p) { g.connect(p); p.connect(mixer.master); } else g.connect(mixer.master);
      mixer.strips.push({gain: g, pan: p});
    }
    return mixer.strips[i];
  }

  // Each strip's gain and pan, from the song: mute and solo are gains too,
  // so a change is heard at once, even on a note already sounding.
  function applyMix(mixer, song, when) {
    for (var i = 0; i < song.ch.length; i++) {
      var s = strip(mixer, i), g = audible(song, i) ? volumeGain(song.ch[i][1]) : 0;
      s.gain.gain.setValueAtTime(g, when);
      if (s.pan) s.pan.pan.setValueAtTime(song.ch[i][2] / 100, when);
    }
    for (var k = song.ch.length; k < mixer.strips.length; k++) mixer.strips[k].gain.gain.setValueAtTime(0, when);
  }

  function play(mixer, channel, sound, velocity, when) {
    var ctx = mixer.ctx, src = ctx.createBufferSource(), v = ctx.createGain();
    src.buffer = mixer.kit[sound];
    v.gain.value = velocity / 9;
    src.connect(v); v.connect(strip(mixer, channel).gain);
    src.start(when);
  }

  // Every note of one step, at `when`.
  function playStep(mixer, song, step, when, log) {
    for (var i = 0; i < song.ch.length; i++) {
      var vel = song.rows[i].charCodeAt(step) - 48;
      if (vel > 0 && vel <= 9 && audible(song, i)) {
        play(mixer, i, song.ch[i][0], vel, when);
        if (log) log.push([i, step, when]);
      }
    }
  }

  // ---- the live studio --------------------------------------------------

  var B = w.beyondBeats = {
    kit: KIT,
    ctx: null, mixer: null, song: cleanSong({}),
    playing: false, step: 0, next: 0, queue: [], shown: -1, log: null,

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
      if (B.step >= B.song.steps) B.step = 0;
      if (B.mixer) applyMix(B.mixer, B.song, B.ctx.currentTime);
      return 'ok';
    },

    start: function () {
      B.unlock();
      if (!B.ctx) return 'none';
      B.playing = true; B.step = 0; B.queue = []; B.shown = -1;
      B.next = B.ctx.currentTime + 0.06;
      B.book();
      return 'ok';
    },

    stop: function () { B.playing = false; B.queue = []; B.shown = -1; return 'ok'; },

    // The step sounding now (counted from 0), or -1 when stopped.
    now: function () {
      if (!B.playing || !B.ctx) return -1;
      var t = B.ctx.currentTime;
      while (B.queue.length && B.queue[0][1] <= t) B.shown = B.queue.shift()[0];
      return B.shown;
    },

    // One channel's sound now, at a velocity: a pad clicked, a name tried.
    hit: function (channel, velocity) {
      B.unlock();
      if (!B.ctx || channel < 0 || channel >= B.song.ch.length) return 'none';
      var mixer = B.mixer;
      strip(mixer, channel);
      // heard even when the channel is muted: the user asked for it
      var ctx = B.ctx, src = ctx.createBufferSource(), v = ctx.createGain(), c = B.song.ch[channel];
      src.buffer = mixer.kit[c[0]];
      v.gain.value = (velocity || 7) / 9 * volumeGain(c[1]);
      var p = ctx.createStereoPanner ? ctx.createStereoPanner() : null;
      src.connect(v);
      if (p) { p.pan.value = c[2] / 100; v.connect(p); p.connect(mixer.master); } else v.connect(mixer.master);
      src.start(ctx.currentTime + 0.005);
      return 'ok';
    },

    // Books every step that starts before the clock is LOOKAHEAD ahead.
    book: function () {
      if (!B.playing || !B.ctx) return;
      var ahead = B.ctx.currentTime + LOOKAHEAD, song = B.song;
      while (B.next < ahead) {
        var at = B.next + swingDelay(song, B.step);
        playStep(B.mixer, song, B.step, at, B.log);
        B.queue.push([B.step, at]);
        B.next += stepLength(song);
        B.step = (B.step + 1) % song.steps;
      }
    },

    // The song, rendered faster than real time: `loops` times through the
    // pattern, then a second for the last sounds to ring out. Resolves to
    // {rate, left, right, log}. raw leaves out the master's limiter (the
    // check measures levels with it out).
    render: function (s, loops, rate, raw) {
      if (!Offline) return Promise.reject(new Error('no OfflineAudioContext'));
      var song = cleanSong(s), n = Math.max(1, loops || 1) * song.steps;
      var seconds = n * stepLength(song) + 1, r = rate || 44100;
      var ctx = new Offline(2, Math.ceil(seconds * r), r), mixer = makeMixer(ctx, !!raw), log = [];
      applyMix(mixer, song, 0);
      for (var k = 0; k < n; k++) {
        var step = k % song.steps;
        playStep(mixer, song, step, k * stepLength(song) + swingDelay(song, step), log);
      }
      return ctx.startRendering().then(function (buf) {
        return {rate: r, left: buf.getChannelData(0), right: buf.getChannelData(1), log: log};
      });
    },

    // for the check
    makeSound: makeSound, cleanSong: cleanSong, audible: audible,
    stepLength: stepLength, swingDelay: swingDelay
  };

  if (Ctx) {
    setInterval(B.book, TICK);
    ['pointerdown', 'mousedown', 'touchend', 'keydown'].forEach(function (e) {
      w.addEventListener(e, B.unlock, true);
    });
  }
})();
window.beyondBeats && (window.AudioContext || window.webkitAudioContext) ? 'ok' : 'none';
