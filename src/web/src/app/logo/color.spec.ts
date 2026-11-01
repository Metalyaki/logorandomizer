import { contrastRatio, hexToRgb, hslToHex, pickTextColor, relativeLuminance } from './color';
import { createRng } from './random';

describe('hslToHex', () => {
  it('converts primary colors', () => {
    expect(hslToHex(0, 100, 50)).toBe('#ff0000');
    expect(hslToHex(120, 100, 50)).toBe('#00ff00');
    expect(hslToHex(240, 100, 50)).toBe('#0000ff');
  });

  it('converts black, white and gray', () => {
    expect(hslToHex(0, 0, 0)).toBe('#000000');
    expect(hslToHex(0, 0, 100)).toBe('#ffffff');
    expect(hslToHex(0, 0, 50)).toBe('#808080');
  });

  it('always returns lowercase #rrggbb', () => {
    const rng = createRng(11);
    for (let i = 0; i < 200; i++) {
      expect(hslToHex(rng() * 360, rng() * 100, rng() * 100)).toMatch(/^#[0-9a-f]{6}$/);
    }
  });
});

describe('hexToRgb', () => {
  it('parses a hex color into r, g, b', () => {
    expect(hexToRgb('#ff8000')).toEqual({ r: 255, g: 128, b: 0 });
    expect(hexToRgb('#000000')).toEqual({ r: 0, g: 0, b: 0 });
  });
});

describe('relativeLuminance', () => {
  it('is 0 for black and 1 for white', () => {
    expect(relativeLuminance('#000000')).toBe(0);
    expect(relativeLuminance('#ffffff')).toBeCloseTo(1, 10);
  });
});

describe('contrastRatio', () => {
  it('is 21 for black on white', () => {
    expect(contrastRatio('#000000', '#ffffff')).toBe(21);
  });

  it('is symmetric', () => {
    expect(contrastRatio('#ffffff', '#000000')).toBe(contrastRatio('#000000', '#ffffff'));
    expect(contrastRatio('#336699', '#ffcc00')).toBe(contrastRatio('#ffcc00', '#336699'));
  });

  it('is 1 for identical colors', () => {
    expect(contrastRatio('#336699', '#336699')).toBeCloseTo(1, 10);
  });
});

describe('pickTextColor', () => {
  it('picks white on black and black on white', () => {
    expect(pickTextColor('#000000')).toBe('#ffffff');
    expect(pickTextColor('#ffffff')).toBe('#000000');
  });

  it('returns black or white with at least 4.5:1 contrast for 1000 backgrounds', () => {
    const rng = createRng(2024);
    for (let i = 0; i < 1000; i++) {
      const bg = hslToHex(rng() * 360, rng() * 100, rng() * 100);
      const text = pickTextColor(bg);
      expect(['#000000', '#ffffff']).toContain(text);
      expect(contrastRatio(text, bg)).toBeGreaterThanOrEqual(4.5);
    }
  });
});
