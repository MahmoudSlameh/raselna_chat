// Captures the marketing screenshots from the example's web build.
//
//   cd example && flutter build web --release
//   node ../tool/capture.cjs            (from the package root: node tool/capture.cjs)
//
// Serves example/build/web on a local port, opens each `?shot=` state at a
// phone viewport (390x844, deviceScaleFactor 3) and writes screenshots/*.png,
// then renders tool/promo.html to screenshots/promo-1080x1350.png.
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const web = path.join(root, 'example', 'build', 'web');
const out = path.join(root, 'screenshots');
const shots = ['welcome', 'menu', 'catalog', 'slots', 'confirm', 'dark'];

const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.css': 'text/css', '.bin': 'application/octet-stream',
  '.frag': 'application/octet-stream', '.svg': 'image/svg+xml',
};

function serve(dir) {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const url = decodeURIComponent(req.url.split('?')[0]);
      let file = path.join(dir, url === '/' ? 'index.html' : url);
      if (!file.startsWith(dir) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
        file = path.join(dir, 'index.html');
      }
      res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
      fs.createReadStream(file).pipe(res);
    });
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

(async () => {
  if (!fs.existsSync(path.join(web, 'index.html'))) {
    console.error('Build the example first: cd example && flutter build web --release');
    process.exit(1);
  }
  fs.mkdirSync(out, { recursive: true });
  const server = await serve(web);
  const base = `http://127.0.0.1:${server.address().port}/`;
  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
    locale: 'ar',
  });
  for (const shot of shots) {
    const page = await context.newPage();
    await page.goto(`${base}?shot=${shot}`, { waitUntil: 'networkidle' });
    await page.waitForSelector('flutter-view, flt-glass-pane', { timeout: 30000 });
    await page.waitForTimeout(2500);
    await page.screenshot({ path: path.join(out, `${shot}.png`) });
    console.log('wrote', `${shot}.png`);
    await page.close();
  }
  await context.close();

  // The 1080x1350 promo (feed portrait), from the phone shots above.
  const promo = await browser.newPage({ viewport: { width: 1080, height: 1350 }, deviceScaleFactor: 1 });
  await promo.goto('file://' + path.join(__dirname, 'promo.html'));
  await promo.waitForTimeout(800);
  await promo.screenshot({ path: path.join(out, 'promo-1080x1350.png') });
  console.log('wrote promo-1080x1350.png');

  await browser.close();
  server.close();
})();
