const { chromium } = require('playwright-core');

(async () => {
  const url = process.argv[2];
  if (!url) process.exit(1);

  const browser = await chromium.launch({
    executablePath: '/usr/bin/chromium-browser',
    headless: true
  });

  const page = await browser.newPage();
  await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });

  const html = await page.content();

  console.log(JSON.stringify({ url, html }));

  await browser.close();
})();
