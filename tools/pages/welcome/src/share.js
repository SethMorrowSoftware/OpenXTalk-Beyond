// Draws the welcome pages' link-preview pictures, share/<card>.jpg, from
// src/share.html: 1200 by 630, the size Facebook, LinkedIn, X,
// Mastodon, Discord and Slack all show large, as JPEG at a quality that
// keeps each under 300 KB (WhatsApp shows no picture for a bigger one).
// The pictures are committed; run this again only when a card changes:
//
//   node tools/pages/welcome/src/share.js
//
// It needs Node and Playwright with its Chromium (npm install playwright,
// then npx playwright install chromium). It serves tools/pages on
// 127.0.0.1 while it draws, because a browser will not use fonts that a
// page opened from the disk names; the cards ask no other host for
// anything.
const { chromium } = require('playwright');
const fs = require('fs');
const http = require('http');
const path = require('path');

const PAGES = path.resolve(__dirname, '..', '..');
const OUT = path.resolve(__dirname, '..', 'share');
const CARDS = ['home', 'guide', 'in-house', 'check'];
const TYPES = { '.html': 'text/html', '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.png': 'image/png', '.jpg': 'image/jpeg' };

function serve() {
  const server = http.createServer((req, res) => {
    const rel = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    const file = path.join(PAGES, rel);
    if (!file.startsWith(PAGES + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      res.writeHead(404); res.end(); return;
    }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise(done => server.listen(0, '127.0.0.1', () => done(server)));
}

(async () => {
  const server = await serve();
  const base = 'http://127.0.0.1:' + server.address().port + '/welcome/src/share.html?card=';
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 });
  const outside = [];
  page.on('request', r => { if (!r.url().startsWith('http://127.0.0.1:') && !r.url().startsWith('data:')) outside.push(r.url()); });
  fs.mkdirSync(OUT, { recursive: true });
  for (const card of CARDS) {
    await page.goto(base + card);
    await page.waitForFunction(() => document.title === 'ready');
    const file = path.join(OUT, card + '.jpg');
    // the highest quality that fits under 300 KB
    for (let quality = 92; quality >= 70; quality -= 4) {
      await page.locator('.card.on').screenshot({ path: file, type: 'jpeg', quality });
      if (fs.statSync(file).size <= 300 * 1024) break;
    }
    console.log(path.relative(process.cwd(), file), Math.round(fs.statSync(file).size / 1024) + ' KB');
  }
  await browser.close();
  server.close();
  if (outside.length) {
    console.error('asked another host: ' + outside.join(', '));
    process.exit(1);
  }
})();
