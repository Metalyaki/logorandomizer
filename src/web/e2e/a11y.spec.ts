import { test, expect, type Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { downloadButton, openApp, previousButton, randomizeButton } from './helpers';

const TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'];

async function scan(page: Page): Promise<void> {
  const results = await new AxeBuilder({ page }).withTags(TAGS).analyze();
  expect(results.violations, JSON.stringify(results.violations, null, 2)).toEqual([]);
}

test('axe: no WCAG 2.2 AA violations after load and after each button', async ({ page }) => {
  await openApp(page);
  await scan(page);

  await randomizeButton(page).click();
  await scan(page);

  await previousButton(page).click();
  await scan(page);

  await Promise.all([page.waitForEvent('download'), downloadButton(page).click()]);
  await scan(page);
});

test('keyboard: Space on Previous until disabled moves focus to Randomize (AC19)', async ({
  page,
}) => {
  await openApp(page);
  const name = () => page.locator('[aria-live="polite"]').textContent();
  await randomizeButton(page).click();
  await randomizeButton(page).click();

  await previousButton(page).focus();
  for (let i = 0; i < 5 && (await previousButton(page).isEnabled()); i++) {
    const before = await name();
    await page.keyboard.press('Space');
    await expect.poll(name).not.toBe(before);
  }
  await expect(previousButton(page)).toBeDisabled();
  await expect(randomizeButton(page)).toBeFocused();
});

test('keyboard: Enter on Download SVG downloads and keeps focus and state (AC19)', async ({
  page,
}) => {
  await openApp(page);
  const name = () => page.locator('[aria-live="polite"]').textContent();
  await randomizeButton(page).click();
  const before = await name();
  const previousEnabled = await previousButton(page).isEnabled();

  await downloadButton(page).focus();
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.keyboard.press('Enter'),
  ]);
  expect(download.suggestedFilename()).toMatch(/\.svg$/);

  await expect(downloadButton(page)).toBeFocused();
  expect(await name()).toBe(before);
  expect(await previousButton(page).isEnabled()).toBe(previousEnabled);
});

test('keyboard: Enter and Space activate Randomize, focus stays, focus ring is visible', async ({
  page,
}) => {
  await openApp(page);
  const name = () => page.locator('[aria-live="polite"]').textContent();
  const before = await name();

  await randomizeButton(page).focus();
  await page.keyboard.press('Enter');
  await expect.poll(name).not.toBe(before);
  const second = await name();
  await expect(randomizeButton(page)).toBeFocused();

  await page.keyboard.press('Space');
  await expect.poll(name).not.toBe(second);
  await expect(randomizeButton(page)).toBeFocused();

  const outline = await randomizeButton(page).evaluate((el) => {
    const s = getComputedStyle(el);
    return { style: s.outlineStyle, width: parseFloat(s.outlineWidth) };
  });
  expect(outline.style).not.toBe('none');
  expect(outline.width).toBeGreaterThan(0);
});
