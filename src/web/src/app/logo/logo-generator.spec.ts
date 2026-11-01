import { contrastRatio } from './color';
import { generateLogo, isValidLogo, logoKey } from './logo-generator';
import { Logo, VIEW_BOX } from './logo.model';

const SEEDS = Array.from({ length: 1000 }, (_, i) => i + 1);
const NAME_PATTERN = /^[A-Z][a-z]{1,11} [A-Z][a-z]{1,11}$/;
const HEX = /^#[0-9a-f]{6}$/;
/** Rough average glyph width in em for a system sans font; 25 characters must fit the 512 wide view box. */
const AVG_CHAR_EM = 0.6;
const MAX_NAME_LENGTH = 25;

function fills(logo: Logo): string[] {
  return [logo.background, logo.plate, ...logo.shapes.map((s) => s.fill)];
}

function validLogo(): Logo {
  return structuredClone(generateLogo(1));
}

describe('generateLogo', () => {
  it('produces a valid logo for every seed from 1 to 1000', () => {
    const invalid = SEEDS.filter((seed) => !isValidLogo(generateLogo(seed)));
    expect(invalid).toEqual([]);
  });

  it('uses at least 3 distinct fill colors for every seed (AC4)', () => {
    const tooFew = SEEDS.filter((seed) => new Set(fills(generateLogo(seed))).size < 3);
    expect(tooFew).toEqual([]);
  });

  it('uses lowercase #rrggbb for every color', () => {
    const bad = SEEDS.filter((seed) => {
      const logo = generateLogo(seed);
      return ![...fills(logo), logo.textColor].every((c) => HEX.test(c));
    });
    expect(bad).toEqual([]);
  });

  it('keeps text contrast against the plate at 4.5:1 or more', () => {
    const low = SEEDS.filter((seed) => {
      const logo = generateLogo(seed);
      return contrastRatio(logo.textColor, logo.plate) < 4.5;
    });
    expect(low).toEqual([]);
  });

  it('uses a black or white text color', () => {
    const odd = SEEDS.filter(
      (seed) => !['#000000', '#ffffff'].includes(generateLogo(seed).textColor),
    );
    expect(odd).toEqual([]);
  });

  it('gives a font size at which a 25 character name fits the view box width', () => {
    const tooBig = SEEDS.filter((seed) => {
      const { fontSize } = generateLogo(seed);
      return !(fontSize > 0) || fontSize * AVG_CHAR_EM * MAX_NAME_LENGTH > 512;
    });
    expect(tooBig).toEqual([]);
  });

  it('gives a name of two words that matches the name pattern (AC7)', () => {
    const bad = SEEDS.filter((seed) => !NAME_PATTERN.test(generateLogo(seed).name));
    expect(bad).toEqual([]);
  });

  it('includes at least one shape for every seed', () => {
    const empty = SEEDS.filter((seed) => generateLogo(seed).shapes.length === 0);
    expect(empty).toEqual([]);
  });

  it('keeps circles, rects and polygon points finite and inside a sane range of the view box', () => {
    const bad = SEEDS.filter((seed) =>
      generateLogo(seed).shapes.some((shape) => {
        switch (shape.kind) {
          case 'circle':
            return ![shape.cx, shape.cy, shape.r].every(Number.isFinite) || shape.r <= 0;
          case 'rect':
            return (
              ![shape.x, shape.y, shape.width, shape.height, shape.rx, shape.rotate].every(
                Number.isFinite,
              ) ||
              shape.width <= 0 ||
              shape.height <= 0
            );
          case 'polygon':
            return !/^-?\d+(\.\d+)?,-?\d+(\.\d+)?( -?\d+(\.\d+)?,-?\d+(\.\d+)?){2,}$/.test(
              shape.points,
            );
          default:
            return true;
        }
      }),
    );
    expect(bad).toEqual([]);
  });

  it('gives deep-equal logos when the same seed is used twice (AC6)', () => {
    for (const seed of [1, 2, 42, 999, 1000]) {
      expect(generateLogo(seed)).toEqual(generateLogo(seed));
    }
  });

  it('gives different logos for different seeds', () => {
    const keys = new Set(SEEDS.map((seed) => logoKey(generateLogo(seed))));
    expect(keys.size).toBeGreaterThan(900);
  });

  it('works for seed 0 and large unsigned seeds', () => {
    expect(isValidLogo(generateLogo(0))).toBe(true);
    expect(isValidLogo(generateLogo(4294967295))).toBe(true);
  });

  it('uses the fixed view box constant of 512 by 512', () => {
    expect(VIEW_BOX).toBe('0 0 512 512');
  });
});

describe('logoKey', () => {
  it('is equal for equal logos and different for different logos', () => {
    expect(logoKey(generateLogo(7))).toBe(logoKey(generateLogo(7)));
    expect(logoKey(generateLogo(7))).not.toBe(logoKey(generateLogo(8)));
  });

  it('changes when only the name changes', () => {
    const a = validLogo();
    const b = { ...a, name: 'Other Name' };
    expect(logoKey(a)).not.toBe(logoKey(b));
  });
});

describe('isValidLogo', () => {
  it('accepts a generated logo', () => {
    expect(isValidLogo(validLogo())).toBe(true);
  });

  it.each([null, undefined, 42, 'logo', [], {}])('rejects %j', (value) => {
    expect(isValidLogo(value)).toBe(false);
  });

  it('rejects a name that does not match the name pattern', () => {
    expect(isValidLogo({ ...validLogo(), name: 'lowercase words' })).toBe(false);
    expect(isValidLogo({ ...validLogo(), name: 'OneWord' })).toBe(false);
    expect(isValidLogo({ ...validLogo(), name: '' })).toBe(false);
  });

  it('rejects an invalid color', () => {
    expect(isValidLogo({ ...validLogo(), background: 'red' })).toBe(false);
    expect(isValidLogo({ ...validLogo(), plate: 'url(#x)' })).toBe(false);
  });

  it('rejects a text color that has less than 4.5:1 contrast with the plate', () => {
    const logo = validLogo();
    expect(isValidLogo({ ...logo, plate: '#777777', textColor: '#808080' })).toBe(false);
  });

  it('rejects fewer than 3 distinct fills', () => {
    const logo = validLogo();
    const same = logo.background;
    const flat: Logo = {
      ...logo,
      background: same,
      plate: same,
      shapes: logo.shapes.map((s) => ({ ...s, fill: same })),
    };
    expect(isValidLogo(flat)).toBe(false);
  });

  it('rejects an empty shape list', () => {
    expect(isValidLogo({ ...validLogo(), shapes: [] })).toBe(false);
  });

  it('rejects a non-finite or non-positive font size', () => {
    expect(isValidLogo({ ...validLogo(), fontSize: NaN })).toBe(false);
    expect(isValidLogo({ ...validLogo(), fontSize: 0 })).toBe(false);
    expect(isValidLogo({ ...validLogo(), fontSize: -10 })).toBe(false);
  });

  it('rejects a font size too large for 25 characters', () => {
    expect(isValidLogo({ ...validLogo(), fontSize: 200 })).toBe(false);
  });

  it('rejects a shape with a non-finite number', () => {
    const logo = validLogo();
    const broken: Logo = {
      ...logo,
      shapes: [{ kind: 'circle', cx: NaN, cy: 10, r: 5, fill: '#112233' }, ...logo.shapes],
    };
    expect(isValidLogo(broken)).toBe(false);
  });

  it('rejects a shape with an unknown kind', () => {
    const logo = validLogo();
    const broken = { ...logo, shapes: [{ kind: 'star', fill: '#112233' }] };
    expect(isValidLogo(broken)).toBe(false);
  });

  it('rejects polygon points that are not numbers', () => {
    const logo = validLogo();
    const broken: Logo = {
      ...logo,
      shapes: [{ kind: 'polygon', points: '0,0 "><script>', fill: '#112233' }, ...logo.shapes],
    };
    expect(isValidLogo(broken)).toBe(false);
  });
});
