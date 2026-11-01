import { test, expect } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import {
  currentName,
  downloadButton,
  expectedFileName,
  openApp,
  previousButton,
  randomizeButton,
} from './helpers';

interface BlobProbe {
  types: string[];
  created: string[];
  revoked: string[];
}

declare global {
  interface Window {
    __probe: BlobProbe;
  }
}

test.beforeEach(async ({ page }) => {
  // Record Blob URL creation and revocation without changing behavior.
  await page.addInitScript(() => {
    const probe: BlobProbe = { types: [], created: [], revoked: [] };
    window.__probe = probe;
    const create = URL.createObjectURL.bind(URL);
    const revoke = URL.revokeObjectURL.bind(URL);
    URL.createObjectURL = (obj: Blob | MediaSource) => {
      const url = create(obj);
      probe.created.push(url);
      if (obj instanceof Blob) probe.types.push(obj.type);
      return url;
    };
    URL.revokeObjectURL = (url: string) => {
      probe.revoked.push(url);
      revoke(url);
    };
  });
});

test('AC14, AC15, AC18: download works under the CSP with the right file', async ({ page }) => {
  const response = await page.goto('/');
  expect(response?.headers()['content-security-policy']).toContain("default-src 'self'");
  await expect(page.locator('app-logo-svg svg')).toBeVisible();

  const name = await currentName(page);
  const viewBox = await page.locator('app-logo-svg svg').getAttribute('viewBox');

  const [download] = await Promise.all([
    page.waitForEvent('download'),
    downloadButton(page).click(),
  ]);

  expect(download.suggestedFilename()).toBe(expectedFileName(name));

  const content = await readFile(await download.path(), 'utf8');
  expect(content).toMatch(/^\s*(<\?xml[^>]*\?>\s*)?<svg\b/);
  expect(content).toContain('xmlns="http://www.w3.org/2000/svg"');
  expect(content).toContain(`viewBox="${viewBox}"`);
  expect(content).toContain(name);
  expect(content).not.toMatch(/<script|\son\w+=|javascript:|<foreignObject/i);

  const probe = await page.evaluate(() => window.__probe);
  expect(probe.types).toEqual(['image/svg+xml']);
});

test('AC17: object URL is revoked and state is unchanged after download', async ({ page }) => {
  await openApp(page);
  await randomizeButton(page).click();
  const nameBefore = await currentName(page);
  const svgBefore = await page.locator('app-logo-svg').innerHTML();
  const previousDisabledBefore = await previousButton(page).isDisabled();

  await Promise.all([page.waitForEvent('download'), downloadButton(page).click()]);

  await expect
    .poll(async () => {
      const p = await page.evaluate(() => window.__probe);
      return p.created.length > 0 && p.created.every((u) => p.revoked.includes(u));
    })
    .toBe(true);

  expect(await currentName(page)).toBe(nameBefore);
  expect(await page.locator('app-logo-svg').innerHTML()).toBe(svgBefore);
  expect(await previousButton(page).isDisabled()).toBe(previousDisabledBefore);
  await expect(randomizeButton(page)).toBeEnabled();
  await expect(downloadButton(page)).toBeEnabled();
});

test('AC15: filename follows the displayed name for several logos', async ({ page }) => {
  await openApp(page);
  for (let i = 0; i < 3; i++) {
    await randomizeButton(page).click();
    const name = await currentName(page);
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      downloadButton(page).click(),
    ]);
    expect(download.suggestedFilename()).toBe(expectedFileName(name));
  }
});
