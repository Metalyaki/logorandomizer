import { test, expect } from '@playwright/test';
import { openApp, randomizeButton } from './helpers';

test('AC21: no animation or transition with reduced motion', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await openApp(page);

  for (let i = 0; i < 3; i++) {
    await randomizeButton(page).click();
    const result = await page.evaluate(() => {
      const offenders: string[] = [];
      for (const el of Array.from(document.querySelectorAll('*'))) {
        const style = getComputedStyle(el);
        const durations = `${style.transitionDuration},${style.animationDuration}`
          .split(',')
          .map((v) => parseFloat(v));
        const tag = el.tagName.toLowerCase();
        if (durations.some((d) => d > 0.001)) offenders.push(tag);
        if (style.animationName !== 'none') offenders.push(`${tag}:animation`);
      }
      return { offenders, running: document.getAnimations().length };
    });
    expect(result.offenders).toEqual([]);
    expect(result.running).toBe(0);
  }
});
