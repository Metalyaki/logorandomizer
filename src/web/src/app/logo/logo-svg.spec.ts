import { ComponentFixture, TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';
import { generateLogo } from './logo-generator';
import { LogoSvg } from './logo-svg';
import { VIEW_BOX } from './logo.model';
import { toSvgString } from './svg-export';

const SEEDS = Array.from({ length: 20 }, (_, i) => i + 1);
// Attributes that only the on-screen element has (accessibility, sizing) or that the
// standalone document needs (xmlns); everything else must match the download.
const SCREEN_ONLY = new Set(['style', 'role', 'aria-label', 'xmlns', 'class']);

interface Snapshot {
  tag: string;
  attrs: [string, string][];
  text: string;
  children: Snapshot[];
}

function snapshot(el: Element, ignore: Set<string>): Snapshot {
  const attrs = Array.from(el.attributes)
    .filter((a) => !ignore.has(a.name) && !a.name.startsWith('_ng') && !a.name.startsWith('ng-'))
    .map((a) => [a.name, a.value] as [string, string])
    .sort((a, b) => a[0].localeCompare(b[0]));
  const children = Array.from(el.children).map((c) => snapshot(c, ignore));
  // Element children only: Angular comment nodes are ignored by construction.
  const text = Array.from(el.childNodes)
    .filter((n) => n.nodeType === Node.TEXT_NODE)
    .map((n) => n.textContent ?? '')
    .join('');
  return { tag: el.localName, attrs, text, children };
}

describe('LogoSvg', () => {
  let fixture: ComponentFixture<LogoSvg>;

  function render(seed: number) {
    const logo = generateLogo(seed);
    fixture.componentRef.setInput('logo', logo);
    fixture.detectChanges();
    return logo;
  }

  function svg(): SVGSVGElement {
    return (fixture.nativeElement as HTMLElement).querySelector('svg') as SVGSVGElement;
  }

  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [LogoSvg] });
    fixture = TestBed.createComponent(LogoSvg);
  });

  it('renders exactly one inline svg element (AC3)', () => {
    render(1);
    expect((fixture.nativeElement as HTMLElement).querySelectorAll('svg').length).toBe(1);
  });

  it('uses the fixed viewBox 0 0 512 512 (AC3)', () => {
    render(1);
    expect(svg().getAttribute('viewBox')).toBe('0 0 512 512');
    expect(svg().getAttribute('viewBox')).toBe(VIEW_BOX);
  });

  it('keeps the default preserveAspectRatio so it scales without distortion (AC3)', () => {
    render(1);
    expect(svg().hasAttribute('preserveAspectRatio')).toBe(false);
  });

  // Assumption: S10 forbids component styles, so the component sets sizing through
  // [style.width] / [style.height] bindings on the svg (CSSOM, CSP safe), not a stylesheet.
  it('scales to its container with width 100% and height auto (AC3)', () => {
    render(1);
    expect(svg().style.width).toBe('100%');
    expect(svg().style.height).toBe('auto');
  });

  it('shows the name as text inside the svg (AC7)', () => {
    const logo = render(3);
    const texts = svg().querySelectorAll('text');
    expect(texts.length).toBe(1);
    expect(texts[0].textContent).toBe(logo.name);
  });

  it('shows a name made of two capitalised words (AC7)', () => {
    render(4);
    expect(svg().querySelector('text')?.textContent).toMatch(/^[A-Z][a-z]{1,11} [A-Z][a-z]{1,11}$/);
  });

  it('uses a system font stack and no web font (AC7)', () => {
    render(5);
    const family = svg().querySelector('text')?.getAttribute('font-family') ?? '';
    expect(family).toContain('sans-serif');
    expect(family).not.toMatch(/url\(|https?:/i);
  });

  it('has role img and the accessible name "Logo: <name>" (AC20)', () => {
    const logo = render(6);
    expect(svg().getAttribute('role')).toBe('img');
    expect(svg().getAttribute('aria-label')).toBe(`Logo: ${logo.name}`);
  });

  it('updates the accessible name and text when the logo input changes (AC20)', () => {
    render(6);
    const next = render(7);
    expect(svg().getAttribute('aria-label')).toBe(`Logo: ${next.name}`);
    expect(svg().querySelector('text')?.textContent).toBe(next.name);
  });

  it('renders the same element tags and attributes as toSvgString for 20 seeds (AC14 parity)', () => {
    for (const seed of SEEDS) {
      const logo = render(seed);
      const exported = new DOMParser().parseFromString(
        toSvgString(logo),
        'image/svg+xml',
      ).documentElement;
      const expected = snapshot(exported, SCREEN_ONLY);
      const actual = snapshot(svg(), SCREEN_ONLY);
      expect(actual, `seed ${seed}`).toEqual(expected);
    }
  });
});
