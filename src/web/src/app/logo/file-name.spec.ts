import { toFileName } from './svg-export';

describe('toFileName', () => {
  it('lowercases and hyphenates "Bold Panda" to bold-panda.svg (AC15)', () => {
    expect(toFileName('Bold Panda')).toBe('bold-panda.svg');
  });

  it('falls back to logo.svg for an empty name', () => {
    expect(toFileName('')).toBe('logo.svg');
  });

  it('falls back to logo.svg for a symbol-only name', () => {
    expect(toFileName('!!! ???')).toBe('logo.svg');
  });

  it('falls back to logo.svg for a non-ASCII-only name', () => {
    expect(toFileName('日本語 ñü')).toBe('logo.svg');
  });

  it('replaces non-ASCII characters inside a name with a single hyphen', () => {
    expect(toFileName('Café Panda')).toBe('caf-panda.svg');
  });

  it('collapses each run of other characters into one hyphen', () => {
    expect(toFileName('Bold   &&  Panda')).toBe('bold-panda.svg');
  });

  it('neutralizes path traversal so no slash, backslash or dot-dot remains', () => {
    const result = toFileName('../../x');
    expect(result).toBe('x.svg');
    expect(result).not.toMatch(/[/\\]/);
    expect(result).not.toContain('..');
  });

  it('limits the base name to 40 characters before .svg', () => {
    const result = toFileName('a'.repeat(100));
    expect(result).toBe('a'.repeat(40) + '.svg');
  });

  it('keeps a name of exactly 40 characters unchanged', () => {
    expect(toFileName('b'.repeat(40))).toBe('b'.repeat(40) + '.svg');
  });

  it('trims leading and trailing symbols', () => {
    expect(toFileName('--**Bold Panda**--')).toBe('bold-panda.svg');
  });

  it('keeps digits', () => {
    expect(toFileName('Panda 42')).toBe('panda-42.svg');
  });

  it('only ever returns a name matching a-z, 0-9 and hyphen followed by .svg', () => {
    for (const input of [
      'Bold Panda',
      '<script>&"',
      '../../etc/passwd',
      'x'.repeat(80),
      '',
      'ÄÖ',
    ]) {
      expect(toFileName(input)).toMatch(/^[a-z0-9]+(-[a-z0-9]+)*\.svg$/);
    }
  });
});
