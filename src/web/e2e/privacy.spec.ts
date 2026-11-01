import { test, expect } from '@playwright/test';
import { downloadButton, openApp, previousButton, randomizeButton } from './helpers';

test('AC22: same-origin requests only, no storage, URL unchanged', async ({
  page,
  context,
  baseURL,
}) => {
  const origin = new URL(baseURL as string).origin;
  const requested: string[] = [];
  page.on('request', (request) => requested.push(request.url()));

  await openApp(page);
  const startUrl = page.url();

  await randomizeButton(page).click();
  await randomizeButton(page).click();
  await previousButton(page).click();
  await Promise.all([page.waitForEvent('download'), downloadButton(page).click()]);

  expect(requested.length).toBeGreaterThan(0);
  for (const url of requested) {
    // blob: URLs are same-origin object URLs created by the page itself.
    const ok = url.startsWith(`${origin}/`) || url.startsWith(`blob:${origin}/`);
    expect(ok, `unexpected request: ${url}`).toBe(true);
  }

  expect(page.url()).toBe(startUrl);
  expect(await context.cookies()).toEqual([]);

  const storage = await page.evaluate(async () => {
    const dbs = 'databases' in indexedDB ? await indexedDB.databases() : [];
    return {
      cookie: document.cookie,
      local: localStorage.length,
      session: sessionStorage.length,
      dbs: dbs.length,
    };
  });
  expect(storage).toEqual({ cookie: '', local: 0, session: 0, dbs: 0 });
});
