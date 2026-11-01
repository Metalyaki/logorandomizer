import { ComponentFixture, TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { App } from './app';
import { generateLogo } from './logo/logo-generator';
import { GENERATE_LOGO, LogoStore } from './logo/logo-store';
import { SEED_SOURCE } from './logo/random';
import { SvgDownload } from './logo/svg-download';

describe('App', () => {
  let fixture: ComponentFixture<App>;
  let root: HTMLElement;
  let store: LogoStore;
  let download: { download: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    let next = 1;
    download = { download: vi.fn() };
    await TestBed.configureTestingModule({
      imports: [App],
      providers: [
        { provide: SEED_SOURCE, useValue: () => next++ },
        { provide: GENERATE_LOGO, useValue: generateLogo },
        { provide: SvgDownload, useValue: download },
      ],
    }).compileComponents();
    store = TestBed.inject(LogoStore);
    fixture = TestBed.createComponent(App);
    document.body.appendChild(fixture.nativeElement);
    root = fixture.nativeElement as HTMLElement;
    await settle();
  });

  async function settle(): Promise<void> {
    fixture.detectChanges();
    await fixture.whenStable();
  }

  /** Native button found by its visible text, which is its accessible name. */
  function button(name: string): HTMLButtonElement {
    const found = Array.from(root.querySelectorAll('button')).find(
      (b) => b.textContent?.trim() === name,
    );
    if (!found) {
      throw new Error(`No <button> named "${name}"`);
    }
    return found;
  }

  async function press(el: HTMLButtonElement): Promise<void> {
    el.click();
    await settle();
  }

  function logoSvg(): SVGElement {
    const svgs = root.querySelectorAll('svg');
    expect(svgs.length).toBe(1);
    return svgs[0];
  }

  function liveRegion(): HTMLElement {
    const region = root.querySelector<HTMLElement>('[aria-live="polite"]');
    if (!region) {
      throw new Error('No aria-live="polite" region');
    }
    return region;
  }

  describe('initial state (AC1)', () => {
    it('shows one logo with its name', () => {
      const logo = store.current();

      expect(logoSvg().textContent).toContain(logo.name);
    });

    it('has Randomize and Download SVG enabled and Previous disabled', () => {
      expect(button('Randomize').disabled).toBe(false);
      expect(button('Download SVG').disabled).toBe(false);
      expect(button('Previous').disabled).toBe(true);
    });

    it('has a heading', () => {
      expect(root.querySelector('h1')?.textContent?.trim()).toBeTruthy();
    });
  });

  describe('Randomize (AC2)', () => {
    it('replaces the logo and its name without reloading', async () => {
      const before = store.current();
      const markupBefore = logoSvg().outerHTML;

      await press(button('Randomize'));

      expect(store.current()).not.toEqual(before);
      expect(logoSvg().outerHTML).not.toBe(markupBefore);
      expect(logoSvg().textContent).toContain(store.current().name);
    });

    it('enables Previous', async () => {
      await press(button('Randomize'));

      expect(button('Previous').disabled).toBe(false);
    });
  });

  describe('Previous (AC10)', () => {
    it('shows the earlier logo with exactly the same markup', async () => {
      const markupBefore = logoSvg().outerHTML;
      await press(button('Randomize'));

      await press(button('Previous'));

      expect(logoSvg().outerHTML).toBe(markupBefore);
    });
  });

  describe('Download SVG', () => {
    it('downloads the current logo', async () => {
      await press(button('Randomize'));

      await press(button('Download SVG'));

      expect(download.download).toHaveBeenCalledTimes(1);
      expect(download.download).toHaveBeenCalledWith(store.current());
    });

    it('does not change the shown logo', async () => {
      const markupBefore = logoSvg().outerHTML;

      await press(button('Download SVG'));

      expect(logoSvg().outerHTML).toBe(markupBefore);
    });
  });

  describe('keyboard (AC19)', () => {
    // Enter and Space on a native <button> fire a click in browsers (jsdom does not
    // synthesize it), so we require native, non-submitting buttons and run the click.
    it.each(['Randomize', 'Previous', 'Download SVG'])(
      '%s is a native button that can be tabbed to',
      async (name) => {
        await press(button('Randomize'));
        const el = button(name);

        expect(el.tagName).toBe('BUTTON');
        expect(el.getAttribute('type')).toBe('button');
        expect(el.tabIndex).toBeGreaterThanOrEqual(0);
        expect(el.getAttribute('role')).toBeNull();
      },
    );

    it('Randomize keeps focus after the action runs', async () => {
      const el = button('Randomize');
      el.focus();
      const before = store.current();

      await press(el);

      expect(store.current()).not.toEqual(before);
      expect(document.activeElement).toBe(el);
    });

    it('Download SVG keeps focus after the action runs', async () => {
      const el = button('Download SVG');
      el.focus();

      await press(el);

      expect(download.download).toHaveBeenCalledTimes(1);
      expect(document.activeElement).toBe(el);
    });

    it('Previous keeps focus while it stays enabled', async () => {
      await press(button('Randomize'));
      await press(button('Randomize'));
      const el = button('Previous');
      el.focus();

      await press(el);

      expect(store.canGoBack()).toBe(true);
      expect(el.disabled).toBe(false);
      expect(document.activeElement).toBe(el);
    });

    it('moves focus to Randomize when Previous turns disabled', async () => {
      await press(button('Randomize'));
      const el = button('Previous');
      el.focus();
      expect(document.activeElement).toBe(el);

      await press(el);

      expect(el.disabled).toBe(true);
      expect(document.activeElement).toBe(button('Randomize'));
    });
  });

  describe('announcements (AC20)', () => {
    it('has a polite live region that is not a focus target', () => {
      const region = liveRegion();

      expect(region.getAttribute('aria-live')).toBe('polite');
      expect(region.tabIndex).toBeLessThan(0);
    });

    it('names the logo in the live region on load', () => {
      expect(liveRegion().textContent).toContain(store.current().name);
    });

    it('changes the live region text when Randomize shows a new logo', async () => {
      const before = liveRegion().textContent;

      await press(button('Randomize'));

      expect(liveRegion().textContent).not.toBe(before);
      expect(liveRegion().textContent).toContain(store.current().name);
    });

    it('changes the live region text back when Previous shows the earlier logo', async () => {
      const first = liveRegion().textContent;
      await press(button('Randomize'));
      const second = liveRegion().textContent;

      await press(button('Previous'));

      expect(liveRegion().textContent).toBe(first);
      expect(liveRegion().textContent).not.toBe(second);
    });

    it('does not move focus when the logo changes', async () => {
      const el = button('Randomize');
      el.focus();

      await press(el);
      await press(el);

      expect(document.activeElement).toBe(el);
    });

    it('gives the logo an accessible name that includes its name', async () => {
      await press(button('Randomize'));
      const svg = logoSvg();

      expect(svg.getAttribute('role')).toBe('img');
      expect(svg.getAttribute('aria-label')).toContain(store.current().name);
    });
  });
});
