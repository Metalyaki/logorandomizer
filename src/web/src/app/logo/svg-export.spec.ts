import { generateLogo } from './logo-generator';
import { Logo, VIEW_BOX } from './logo.model';
import { toSvgString } from './svg-export';

const SEEDS = Array.from({ length: 200 }, (_, i) => i + 1);
const SVG_NS = 'http://www.w3.org/2000/svg';
const ALLOWED = new Set(['svg', 'rect', 'circle', 'polygon', 'text', 'g']);

function parse(svg: string): Document {
  return new DOMParser().parseFromString(svg, 'image/svg+xml');
}

function hasParseError(doc: Document): boolean {
  return doc.getElementsByTagName('parsererror').length > 0;
}

function handBuilt(name: string): Logo {
  return {
    name,
    background: '#112233',
    shapes: [{ kind: 'circle', cx: 256, cy: 200, r: 80, fill: '#ffcc00' }],
    plate: '#ffffff',
    textColor: '#000000',
    fontSize: 32,
  };
}

describe('toSvgString', () => {
  it('has a root svg element with the SVG namespace and the same viewBox (AC14)', () => {
    const doc = parse(toSvgString(generateLogo(1)));
    const root = doc.documentElement;
    expect(root.localName).toBe('svg');
    expect(root.namespaceURI).toBe(SVG_NS);
    expect(root.getAttribute('xmlns')).toBe(SVG_NS);
    expect(root.getAttribute('viewBox')).toBe(VIEW_BOX);
  });

  it('contains one element per shape of the logo (AC14)', () => {
    for (const seed of [1, 2, 3, 4, 5]) {
      const logo = generateLogo(seed);
      const doc = parse(toSvgString(logo));
      for (const kind of ['circle', 'rect', 'polygon'] as const) {
        const expected = logo.shapes.filter((s) => s.kind === kind).length;
        const emblemCount = doc.getElementsByTagName(kind).length;
        // rect may also be used for the background and plate, so require at least the shapes
        expect(emblemCount).toBeGreaterThanOrEqual(expected);
      }
      expect(doc.getElementsByTagName('text').length).toBe(1);
    }
  });

  it('contains the name as the text content (AC14)', () => {
    const logo = generateLogo(7);
    const doc = parse(toSvgString(logo));
    expect(doc.getElementsByTagName('text')[0].textContent).toBe(logo.name);
  });

  it('uses the logo colors and font size', () => {
    const logo = handBuilt('Bold Panda');
    const svg = toSvgString(logo);
    for (const color of [logo.background, logo.plate, logo.textColor, '#ffcc00']) {
      expect(svg).toContain(color);
    }
    expect(svg).toContain('32');
  });

  it('is deterministic for the same logo', () => {
    const logo = generateLogo(11);
    expect(toSvgString(logo)).toBe(toSvgString(structuredClone(logo)));
  });

  describe('safety (AC16)', () => {
    it('parses as XML without a parsererror for 200 seeds', () => {
      const broken = SEEDS.filter((seed) => hasParseError(parse(toSvgString(generateLogo(seed)))));
      expect(broken).toEqual([]);
    });

    it('uses only svg, rect, circle, polygon, text and g elements for 200 seeds', () => {
      const bad = SEEDS.filter((seed) => {
        const doc = parse(toSvgString(generateLogo(seed)));
        return Array.from(doc.getElementsByTagName('*')).some((el) => !ALLOWED.has(el.localName));
      });
      expect(bad).toEqual([]);
    });

    it('has no script, foreignObject, on* attribute, href, xlink:href or url( for 200 seeds', () => {
      const bad = SEEDS.filter((seed) => {
        const svg = toSvgString(generateLogo(seed));
        const doc = parse(svg);
        const attrs = Array.from(doc.getElementsByTagName('*')).flatMap((el) =>
          Array.from(el.attributes).map((a) => a.name.toLowerCase()),
        );
        return (
          doc.getElementsByTagName('script').length > 0 ||
          doc.getElementsByTagName('foreignObject').length > 0 ||
          attrs.some((n) => n.startsWith('on') || n === 'href' || n.endsWith(':href')) ||
          svg.includes('url(') ||
          /<script|foreignObject/i.test(svg)
        );
      });
      expect(bad).toEqual([]);
    });

    it('escapes a hostile name so it stays text and the file still parses', () => {
      const svg = toSvgString(handBuilt('<script>&"'));
      const doc = parse(svg);
      expect(hasParseError(doc)).toBe(false);
      expect(svg).not.toContain('<script');
      expect(doc.getElementsByTagName('script').length).toBe(0);
      expect(svg).toContain('&lt;script&gt;&amp;');
      expect(doc.getElementsByTagName('text')[0].textContent).toBe('<script>&"');
    });

    it('escapes hostile attribute values so they cannot break out of the attribute', () => {
      const logo = handBuilt('Safe');
      logo.background = '"><script>alert(1)</script>';
      logo.shapes = [{ kind: 'polygon', points: '0,0" onload="x', fill: '#fff" onclick="y' }];
      const svg = toSvgString(logo);
      const doc = parse(svg);
      expect(hasParseError(doc)).toBe(false);
      expect(doc.getElementsByTagName('script').length).toBe(0);
      const attrs = Array.from(doc.getElementsByTagName('*')).flatMap((el) =>
        Array.from(el.attributes).map((a) => a.name.toLowerCase()),
      );
      expect(attrs.some((n) => n.startsWith('on'))).toBe(false);
    });
  });
});
