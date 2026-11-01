import { generateName } from './name';
import { WORDS } from './words';

/** Small deterministic LCG stub, values in [0, 1). Local on purpose: random.ts is built in parallel. */
function stubRng(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

const NAME_PATTERN = /^[A-Z][a-z]{1,11} [A-Z][a-z]{1,11}$/;

describe('generateName', () => {
  it('returns exactly two words separated by one space', () => {
    const name = generateName(stubRng(1));
    expect(name.split(' ')).toHaveLength(2);
  });

  it('returns two words that both come from WORDS', () => {
    for (let seed = 1; seed <= 200; seed++) {
      const [first, second] = generateName(stubRng(seed)).split(' ');
      expect(WORDS).toContain(first);
      expect(WORDS).toContain(second);
    }
  });

  it('matches the AC7 name pattern for 200 different rng sequences', () => {
    for (let seed = 1; seed <= 200; seed++) {
      expect(generateName(stubRng(seed))).toMatch(NAME_PATTERN);
    }
  });

  it('gives the same name for the same rng sequence', () => {
    expect(generateName(stubRng(42))).toBe(generateName(stubRng(42)));
  });

  it('gives different names across different rng sequences', () => {
    const names = new Set<string>();
    for (let seed = 1; seed <= 50; seed++) {
      names.add(generateName(stubRng(seed)));
    }
    expect(names.size).toBeGreaterThan(1);
  });

  it('stays within 25 characters for 500 rng sequences', () => {
    for (let seed = 1; seed <= 500; seed++) {
      expect(generateName(stubRng(seed)).length).toBeLessThanOrEqual(25);
    }
  });

  it('stays valid at the rng extremes 0 and just below 1', () => {
    const low = generateName(() => 0);
    const high = generateName(() => 0.9999999999);
    expect(low).toMatch(NAME_PATTERN);
    expect(high).toMatch(NAME_PATTERN);
    expect(low.length).toBeLessThanOrEqual(25);
    expect(high.length).toBeLessThanOrEqual(25);
  });
});
