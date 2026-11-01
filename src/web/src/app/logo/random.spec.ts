import { TestBed } from '@angular/core/testing';
import { createRng, SEED_SOURCE } from './random';

function take(rng: () => number, n: number): number[] {
  return Array.from({ length: n }, () => rng());
}

describe('createRng', () => {
  it('gives the same sequence for the same seed', () => {
    expect(take(createRng(12345), 100)).toEqual(take(createRng(12345), 100));
  });

  it('gives different sequences for different seeds', () => {
    expect(take(createRng(1), 20)).not.toEqual(take(createRng(2), 20));
  });

  it('returns values in [0, 1) for 10000 draws', () => {
    const rng = createRng(42);
    for (const value of take(rng, 10000)) {
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThan(1);
    }
  });

  it('does not return the same value over and over', () => {
    expect(new Set(take(createRng(7), 100)).size).toBeGreaterThan(90);
  });

  it('accepts the boundary seeds 0 and 2**32 - 1', () => {
    for (const seed of [0, 2 ** 32 - 1]) {
      const values = take(createRng(seed), 50);
      expect(values.every((v) => v >= 0 && v < 1)).toBe(true);
    }
  });
});

describe('SEED_SOURCE', () => {
  it('by default returns an integer in [0, 2**32)', () => {
    const source = TestBed.inject(SEED_SOURCE);
    for (let i = 0; i < 50; i++) {
      const seed = source();
      expect(Number.isInteger(seed)).toBe(true);
      expect(seed).toBeGreaterThanOrEqual(0);
      expect(seed).toBeLessThan(2 ** 32);
    }
  });

  it('can be replaced by a fake source', () => {
    TestBed.configureTestingModule({ providers: [{ provide: SEED_SOURCE, useValue: () => 99 }] });
    expect(TestBed.inject(SEED_SOURCE)()).toBe(99);
  });
});
