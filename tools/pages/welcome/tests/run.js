/* The stack checker's tests: node tests/run.js, from the site's folder.
   Each test file, and the two sample stacks the checker page offers, must
   get the verdict written beside it. Give file names instead to print the
   report of any stack: node tests/run.js "My Stack.livecode" Old.zip
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
  ['Truncated.livecode', ['doubt']]     // cut short
];
const SAMPLES = { 'Book Library.livecode': ['opens'], 'Balls.livecode': ['notes'] };

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
  const check = async (name, bytes, want) => {
    const got = (await SC.inspectFile(name, bytes)).map(r => r.verdict);
    const ok = got.length === want.length && got.every((v, i) => v === want[i]);
    if (!ok) failed++;
    console.log((ok ? 'ok    ' : 'FAIL  ') + name + ': ' + got.join(', ') + (ok ? '' : '  (expected ' + want.join(', ') + ')'));
  };
  for (const [name, want] of EXPECT) await check(name, new Uint8Array(fs.readFileSync(path.join(FILES, name))), want);
  const box = { window: {} };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '..', 'assets', 'sample-stacks.js'), 'utf8'), box);
  for (const s of box.window.SAMPLE_STACKS) await check(s.name, new Uint8Array(Buffer.from(s.data, 'base64')), SAMPLES[s.name]);
  console.log(failed ? '\n' + failed + ' failed' : '\nAll passed');
  process.exitCode = failed ? 1 : 0;
})();
