import { test, expect } from '@playwright/test';

test.describe('without JavaScript', () => {
  test.use({ javaScriptEnabled: false });

  test('shows the noscript message and no app', async ({ page }) => {
    await page.goto('/');
    // Playwright inspects the DOM with scripting on, so noscript renders as hidden
    // text there; innerHTML is the reliable check that the message is shipped.
    const html = await page.locator('noscript').evaluate((el) => el.innerHTML);
    expect(html).toBe('This app needs JavaScript');
    await expect(page.locator('app-root')).toBeEmpty();
    await expect(page.getByRole('button')).toHaveCount(0);
  });
});
