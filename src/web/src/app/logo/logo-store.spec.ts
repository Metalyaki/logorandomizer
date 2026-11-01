import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';
import { generateLogo, isValidLogo, logoKey } from './logo-generator';
import type { Logo } from './logo.model';
import { GENERATE_LOGO, LogoStore } from './logo-store';
import { SEED_SOURCE } from './random';

/** Seed source that returns start, start + 1, ... */
function counterSeeds(start: number): () => number {
  let next = start;
  return () => next++;
}

/** Seed source that returns the given seeds in order, then keeps returning the last one. */
function sequenceSeeds(seeds: readonly number[]): () => number {
  let i = 0;
  return () => seeds[Math.min(i++, seeds.length - 1)];
}

function createStore(
  seedSource: () => number,
  generate: (seed: number) => Logo = generateLogo,
): LogoStore {
  TestBed.configureTestingModule({
    providers: [
      { provide: SEED_SOURCE, useValue: seedSource },
      { provide: GENERATE_LOGO, useValue: generate },
    ],
  });
  return TestBed.inject(LogoStore);
}

describe('LogoStore', () => {
  describe('initial state (AC1)', () => {
    it('starts with a valid logo', () => {
      const store = createStore(counterSeeds(1));

      expect(isValidLogo(store.current())).toBe(true);
    });

    it('cannot go back before the first randomize', () => {
      const store = createStore(counterSeeds(1));

      expect(store.canGoBack()).toBe(false);
      expect(store.history().past).toEqual([]);
    });
  });

  describe('randomize (AC2)', () => {
    it('replaces the current logo with a different valid logo', () => {
      const store = createStore(counterSeeds(1));
      const before = store.current();

      store.randomize();

      expect(logoKey(store.current())).not.toBe(logoKey(before));
      expect(isValidLogo(store.current())).toBe(true);
    });

    it('allows going back after a randomize', () => {
      const store = createStore(counterSeeds(1));

      store.randomize();

      expect(store.canGoBack()).toBe(true);
    });
  });

  describe('no repeated logos (AC5)', () => {
    it('never shows the same logo twice in a row over 100 presses and yields at least 90 distinct logos', () => {
      const store = createStore(counterSeeds(1000));
      const keys = [logoKey(store.current())];

      for (let i = 0; i < 100; i++) {
        store.randomize();
        keys.push(logoKey(store.current()));
      }

      for (let i = 1; i < keys.length; i++) {
        expect(keys[i]).not.toBe(keys[i - 1]);
      }
      expect(new Set(keys).size).toBeGreaterThanOrEqual(90);
    });

    it('still yields a different logo when the seed source repeats the seed of the current logo', () => {
      // initial logo uses seed 7; the first presses draw 7 again, then 8
      const store = createStore(sequenceSeeds([7, 7, 7, 8]));
      const before = logoKey(store.current());

      store.randomize();

      expect(logoKey(store.current())).not.toBe(before);
      expect(isValidLogo(store.current())).toBe(true);
    });
  });

  describe('previous (AC10)', () => {
    it('returns the earlier logo and drops the one that was left', () => {
      const store = createStore(counterSeeds(1));
      const first = store.current();
      store.randomize();

      store.previous();

      expect(store.current()).toEqual(first);
      expect(store.canGoBack()).toBe(false);
    });

    it('does nothing when there is nothing to go back to', () => {
      const store = createStore(counterSeeds(1));
      const first = store.current();

      store.previous();

      expect(store.current()).toEqual(first);
      expect(store.canGoBack()).toBe(false);
    });
  });

  describe('history cap (AC11)', () => {
    it('keeps only the 20 most recent earlier logos after 25 presses', () => {
      const store = createStore(counterSeeds(1));
      const shown = [logoKey(store.current())];
      for (let i = 0; i < 25; i++) {
        store.randomize();
        shown.push(logoKey(store.current()));
      }

      let steps = 0;
      while (store.canGoBack()) {
        store.previous();
        steps++;
      }

      expect(steps).toBe(20);
      // shown has 26 entries; the oldest 5 are gone, the oldest reachable is index 5
      expect(logoKey(store.current())).toBe(shown[5]);
    });

    it('keeps past.length at or below 20 after 1000 presses (SR5)', () => {
      const store = createStore(counterSeeds(1));

      for (let i = 0; i < 1000; i++) {
        store.randomize();
        expect(store.history().past.length).toBeLessThanOrEqual(20);
      }

      expect(store.history().past.length).toBe(20);
    });
  });

  describe('randomize after previous (AC12)', () => {
    it('keeps the logo that was current before the new one and continues from there', () => {
      const store = createStore(counterSeeds(1));
      const a = store.current();
      store.randomize();
      store.randomize();

      store.previous();
      const b = store.current();
      store.randomize();
      const c = store.current();

      expect(logoKey(c)).not.toBe(logoKey(b));
      store.previous();
      expect(store.current()).toEqual(b);
      store.previous();
      expect(store.current()).toEqual(a);
      expect(store.canGoBack()).toBe(false);
    });

    it('can step back to the logo shown before a randomize that followed a previous', () => {
      const store = createStore(counterSeeds(1));
      store.randomize();
      const second = store.current();
      store.randomize();
      store.previous();
      expect(store.current()).toEqual(second);

      store.randomize();
      store.previous();

      expect(store.current()).toEqual(second);
    });
  });

  describe('failing generator', () => {
    it('keeps the current logo and history when the generator returns an invalid logo', () => {
      let broken = false;
      const store = createStore(counterSeeds(1), (seed) =>
        broken
          ? { ...generateLogo(seed), name: 'not a valid name', shapes: [] }
          : generateLogo(seed),
      );
      const before = store.current();
      const pastBefore = store.history().past;
      broken = true;

      expect(() => store.randomize()).not.toThrow();

      expect(store.current()).toEqual(before);
      expect(store.history().past).toEqual(pastBefore);
      expect(store.canGoBack()).toBe(false);
    });

    it('keeps the current logo and history when the generator throws', () => {
      let failing = false;
      const store = createStore(counterSeeds(1), (seed) => {
        if (failing) {
          throw new Error('boom');
        }
        return generateLogo(seed);
      });
      store.randomize();
      const before = store.current();
      const pastBefore = store.history().past;
      failing = true;

      expect(() => store.randomize()).not.toThrow();

      expect(store.current()).toEqual(before);
      expect(store.history().past).toEqual(pastBefore);
    });

    it('recovers on the next press once the generator works again', () => {
      let failing = false;
      const store = createStore(counterSeeds(1), (seed) => {
        if (failing) {
          throw new Error('boom');
        }
        return generateLogo(seed);
      });
      const before = store.current();
      failing = true;
      store.randomize();
      failing = false;

      store.randomize();

      expect(logoKey(store.current())).not.toBe(logoKey(before));
    });
  });
});
