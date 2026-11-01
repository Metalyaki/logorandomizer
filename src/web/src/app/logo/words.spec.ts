import { WORDS } from './words';

describe('WORDS', () => {
  it('has at least 50 entries', () => {
    expect(WORDS.length).toBeGreaterThanOrEqual(50);
  });

  it('has only entries that are a capital letter followed by 1 to 11 lowercase letters', () => {
    const pattern = /^[A-Z][a-z]{1,11}$/;
    const invalid = WORDS.filter((word) => !pattern.test(word));
    expect(invalid).toEqual([]);
  });

  it('has no duplicate entries', () => {
    const duplicates = WORDS.filter((word, index) => WORDS.indexOf(word) !== index);
    expect(duplicates).toEqual([]);
  });
});
