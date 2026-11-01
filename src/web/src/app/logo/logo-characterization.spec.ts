import { fnv1a } from './characterization-hash';
import { generateLogo } from './logo-generator';
import { LOGO_FIXTURE, SVG_HASH_FIXTURE } from './logo-characterization.fixture';
import { toSvgString } from './svg-export';

const SEEDS = Array.from({ length: 200 }, (_, i) => i + 1);

describe('characterization: current output is pinned (plan 0002 S1)', () => {
  it('has a fixture entry for each of the 200 seeds', () => {
    expect(LOGO_FIXTURE.length).toBe(SEEDS.length);
    expect(SVG_HASH_FIXTURE.length).toBe(SEEDS.length);
  });

  it.each(SEEDS)('generateLogo(%i) equals the committed snapshot', (seed) => {
    // JSON round trip: the fixture is JSON, which stores a computed -0 as 0.
    expect(JSON.parse(JSON.stringify(generateLogo(seed)))).toEqual(LOGO_FIXTURE[seed - 1]);
  });

  it.each(SEEDS)('toSvgString(generateLogo(%i)) hashes to the committed value', (seed) => {
    expect(fnv1a(toSvgString(generateLogo(seed)))).toBe(SVG_HASH_FIXTURE[seed - 1]);
  });
});
