import { expect, type Page } from '@playwright/test';

export const randomizeButton = (page: Page) => page.getByRole('button', { name: 'Randomize' });
export const previousButton = (page: Page) => page.getByRole('button', { name: 'Previous' });
export const downloadButton = (page: Page) => page.getByRole('button', { name: 'Download SVG' });

/** Opens the app and waits until the first logo is rendered. */
export async function openApp(page: Page): Promise<void> {
  await page.goto('/');
  await expect(page.locator('app-logo-svg svg')).toBeVisible();
}

/** The current logo name, read from the polite live region. */
export async function currentName(page: Page): Promise<string> {
  const text = (await page.locator('[aria-live="polite"]').textContent()) ?? '';
  return text.replace(/^\s*New logo:\s*/, '').trim();
}

/** Independent implementation of the AC15 filename rule. */
export function expectedFileName(name: string): string {
  const base = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40)
    .replace(/^-+|-+$/g, '');
  return `${base || 'logo'}.svg`;
}
