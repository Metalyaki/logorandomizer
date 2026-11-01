import { InjectionToken } from '@angular/core';

/** mulberry32: a small seedable 32 bit PRNG. Non-cryptographic by design. */
export function createRng(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Source of fresh seeds (non-cryptographic); tests replace it with a fake. */
export const SEED_SOURCE = new InjectionToken<() => number>('SEED_SOURCE', {
  providedIn: 'root',
  factory: () => () => Math.floor(Math.random() * 2 ** 32),
});
