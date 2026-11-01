import { test, expect } from '@playwright/test';
import { downloadButton, previousButton, randomizeButton } from './helpers';

test('SR6, AC3: no console errors or CSP violations while using every button', async ({ page }) => {
  const problems: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error' || msg.type() === 'warning') {
      problems.push(`console ${msg.type()}: ${msg.text()}`);
    }
  });
  page.on('pageerror', (err) => problems.push(`pageerror: ${err.message}`));
  await page.addInitScript(() => {
    document.addEventListener('securitypolicyviolation', (e) => {
      console.error(`CSP violation: ${e.violatedDirective} ${e.blockedURI}`);
    });
  });

  const response = await page.goto('/');
  const headers = response!.headers();
  expect(headers['content-security-policy']).toContain("script-src 'self'");
  expect(headers['x-content-type-options']).toBe('nosniff');
  await expect(page.locator('app-logo-svg svg')).toBeVisible();

  await randomizeButton(page).click();
  await randomizeButton(page).click();
  await previousButton(page).click();
  await Promise.all([page.waitForEvent('download'), downloadButton(page).click()]);
  await randomizeButton(page).click();

  // AC3: a single inline SVG with a fixed viewBox.
  await expect(page.locator('app-logo-svg svg')).toHaveCount(1);
  await expect(page.locator('app-logo-svg svg')).toHaveAttribute('viewBox', '0 0 512 512');

  expect(problems).toEqual([]);
});
