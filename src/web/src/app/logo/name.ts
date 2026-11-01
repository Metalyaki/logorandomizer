import { WORDS } from './words';

/** Two random words from WORDS joined by one space. */
export function generateName(rng: () => number): string {
  const pick = (): string => WORDS[Math.floor(rng() * WORDS.length)];
  return `${pick()} ${pick()}`;
}
