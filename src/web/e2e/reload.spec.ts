import { test, expect } from '@playwright/test';
import { openApp, previousButton, randomizeButton } from './helpers';

test('AC13: reload shows a fresh logo and Previous is disabled', async ({ page }) => {
  await openApp(page);
  await randomizeButton(page).click();
  await randomizeButton(page).click();
  await expect(previousButton(page)).toBeEnabled();

  await page.reload();
  await expect(page.locator('app-logo-svg svg')).toBeVisible();
  await expect(previousButton(page)).toBeDisabled();
});
