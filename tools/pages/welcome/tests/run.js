/* The stack checker's tests: node tests/run.js, from the site's folder.
   Each test file, and the two sample stacks the checker page offers, must
   get the verdict written beside it; the stacks below, the platforms their
   Standalone Settings have ticked; and the scripts below, the calls they
   make. Give file names instead to print the report of any stack:
   node tests/run.js "My Stack.livecode" Old.zip
   Node 18 or later (the zip reader needs DecompressionStream). */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const SC = require('../assets/stackcheck.js');

const FILES = path.join(__dirname, 'files');
const EXPECT = [
  ['CRLF.rev', ['blocked']],            // line endings changed by a text-mode copy
  ['Empty.livecode', ['unknown']],
  ['Encrypted.livecode', ['blocked']],  // password-protected
  ['Lib.livecodescript', ['notes']],    // a script-only stack that calls tsNet
  ['Newer.livecode', ['blocked']],      // a format newer than 8.1
  ['NoStack.zip', ['unknown']],
  ['Project.zip', ['opens', 'notes']],  // a binary stack and a script-only one, in folders
  ['Random.livecode', ['unknown']],
  ['Recorder.livecode', ['opens']],
  ['Toast.livecode', ['opens']],        // set up for Android only, so no iOS note
  ['Truncated.livecode', ['doubt']],    // cut short
  ['Video Player.oxtstack', ['opens']]
];
const SAMPLES = { 'Book Library.livecode': ['opens'], 'Balls.livecode': ['notes'] };

// The platforms ticked in each stack's Standalone Settings, as OXT-Beyond's
// engine reads them: the customProperties["cRevStandaloneSettings"] of the
// stack, read with messages locked by the 0.2.8-dp.1 engine on 2026-11-22.
// Toast.livecode and Recorder.livecode are the 8.1 samples of the toast
// and androidaudiorecorder libraries (extensions/libraries), and Video
// Player.oxtstack the 7.0 one in tools/examples/originals: their settings
// hold strings and booleans, true and false, and keys for platforms that
// are not ticked, as Balls's (5.5) do.
const PLATFORMS = [
  ['Toast.livecode', ['Android']],                                // ios is there, and false
  ['Recorder.livecode', ['Windows', 'macOS', 'Linux', 'Android']], // the Mac's is a boolean
  ['Video Player.oxtstack', ['Linux']],                           // MacOSX x86-32 is a boolean false
  ['Balls.livecode', ['Android', 'iOS']],                         // Windows and the Macs are false
  ['Book Library.livecode', []]                                   // no settings
];

// Script-only stacks, and the calls each must be found to make: the names
// listed, as first written; null for a kind that must not be found. The
// engine finds a handler however its name is capitalized, and English
// words are not calls.
const SCRIPTS = [
  ['Lower.livecodescript', 'script "Lower"\n' +
    'on mouseUp\n  mergavcamstart\n  mergAVCamStart\n  MERGAVCAMSTART\n' +
    '  get tsnetgetsync("https://example.com", tHeaders, tStatus)\n' +
    '  put URL "https://example.com" into tPage\nend mouseUp\n',
    'notes', { mergext: ['mergavcamstart'], tsnet: ['tsnetgetsync'], url: [] }],
  ['Words.livecodescript', 'script "Words"\n' +
    '-- Merged, merges, merging and MERGED are words, and mergeSort is ours.\n' +
    'on mergeSort pList\n  return mergeLists(pList)\nend mergeSort\n',
    'opens', { mergext: null }]
];

async function report(name, bytes) {
  const reps = await SC.inspectFile(name, bytes);
  for (const r of reps) {
    console.log('\n' + (r.path || r.fileName) + ': ' + r.verdict);
    console.log(SC.toText(r));
  }
}

(async () => {
  const args = process.argv.slice(2);
  if (args.length) {
    for (const f of args) await report(path.basename(f), new Uint8Array(fs.readFileSync(f)));
    return;
  }
  let failed = 0;
  const say = (ok, name, got, want) => {
    if (!ok) failed++;
    console.log((ok ? 'ok    ' : 'FAIL  ') + name + ': ' + got + (ok ? '' : '  (expected ' + want + ')'));
  };
  const check = async (name, bytes, want) => {
    const got = (await SC.inspectFile(name, bytes)).map(r => r.verdict);
    say(got.length === want.length && got.every((v, i) => v === want[i]), name, got.join(', '), want.join(', '));
  };
  const stacks = {};
  for (const [name, want] of EXPECT) {
    stacks[name] = new Uint8Array(fs.readFileSync(path.join(FILES, name)));
    await check(name, stacks[name], want);
  }
  const box = { window: {} };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '..', 'assets', 'sample-stacks.js'), 'utf8'), box);
  for (const s of box.window.SAMPLE_STACKS) {
    stacks[s.name] = new Uint8Array(Buffer.from(s.data, 'base64'));
    await check(s.name, stacks[s.name], SAMPLES[s.name]);
  }
  for (const [name, want] of PLATFORMS) {
    const got = SC.inspect(stacks[name], name).platforms;
    say(got.join(', ') === want.join(', '), name + ' is set up for', got.join(', ') || 'nothing', want.join(', ') || 'nothing');
  }
  for (const [name, text, verdict, calls] of SCRIPTS) {
    const r = SC.inspect(new Uint8Array(Buffer.from(text, 'utf8')), name);
    const found = {};
    r.findings.forEach(f => { if (f.id) found[f.id] = f.names; });
    const got = [r.verdict].concat(Object.keys(calls).map(id => id + ' ' + (found[id] ? '[' + found[id].join(', ') + ']' : 'none')));
    const want = [verdict].concat(Object.keys(calls).map(id => id + ' ' + (calls[id] ? '[' + calls[id].join(', ') + ']' : 'none')));
    say(got.join('; ') === want.join('; '), name, got.join('; '), want.join('; '));
  }
  console.log(failed ? '\n' + failed + ' failed' : '\nAll passed');
  process.exitCode = failed ? 1 : 0;
})();
