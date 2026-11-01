import { test, expect } from '@playwright/test';
import { downloadButton, openApp, previousButton, randomizeButton } from './helpers';

for (const width of [320, 375, 768, 1280, 1920]) {
  test(`AC23: everything visible without horizontal scroll at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 800 });
    await openApp(page);

    const overflow = await page.evaluate(() => ({
      doc: document.documentElement.scrollWidth - document.documentElement.clientWidth,
      body: document.body.scrollWidth - document.body.clientWidth,
    }));
    expect(overflow.doc).toBeLessThanOrEqual(0);
    expect(overflow.body).toBeLessThanOrEqual(0);

    const buttons = [randomizeButton(page), previousButton(page), downloadButton(page)];
    const targets = [
      page.locator('app-logo-svg svg'),
      page.locator('app-logo-svg svg text'),
      ...buttons,
    ];
    for (const target of targets) {
      await expect(target).toBeVisible();
      const box = await target.boundingBox();
      expect(box).not.toBeNull();
      expect(box!.x).toBeGreaterThanOrEqual(0);
      expect(box!.x + box!.width).toBeLessThanOrEqual(width + 0.5);
    }

    for (const button of buttons) {
      const box = await button.boundingBox();
      expect(box!.width).toBeGreaterThanOrEqual(24);
      expect(box!.height).toBeGreaterThanOrEqual(24);
    }

    // The logo name must fit inside the logo, not be clipped.
    const fits = await page.evaluate(() => {
      const text = document.querySelector('app-logo-svg svg text') as SVGTextElement;
      const box = text.getBBox();
      return box.x >= 0 && box.x + box.width <= 512;
    });
    expect(fits).toBe(true);
  });
}
