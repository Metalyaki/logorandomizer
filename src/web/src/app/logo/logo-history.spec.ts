import { describe, expect, it } from 'vitest';
import type { Logo } from './logo.model';
import { back, push, type History } from './logo-history';

function makeLogo(n: number): Logo {
  return {
    name: `Logo${n}`,
    background: '#112233',
    shapes: [],
    plate: '#ffffff',
    textColor: '#000000',
    fontSize: 32,
  };
}

function start(n = 0): History {
  return { current: makeLogo(n), past: [] };
}

function deepFreeze<T>(value: T): T {
  if (value && typeof value === 'object') {
    Object.values(value).forEach(deepFreeze);
    Object.freeze(value);
  }
  return value;
}

describe('logo-history push', () => {
  it('makes the pushed logo current and moves the previous current to past', () => {
    const next = push(start(0), makeLogo(1));

    expect(next.current).toEqual(makeLogo(1));
    expect(next.past).toEqual([makeLogo(0)]);
  });

  it('does not mutate its input', () => {
    const input = deepFreeze(start(0));
    const snapshot = structuredClone(input);

    expect(() => push(input, makeLogo(1))).not.toThrow();
    expect(input).toEqual(snapshot);
  });

  it('returns a new past array instead of the input array', () => {
    const input = start(0);

    expect(push(input, makeLogo(1)).past).not.toBe(input.past);
  });

  it('keeps at most 20 past entries after 25 pushes and drops the oldest first (AC11)', () => {
    let h = start(0);
    for (let i = 1; i <= 25; i++) {
      h = push(h, makeLogo(i));
    }

    expect(h.current).toEqual(makeLogo(25));
    expect(h.past).toHaveLength(20);
    expect(h.past[0]).toEqual(makeLogo(5));
    expect(h.past[19]).toEqual(makeLogo(24));
  });

  it('allows exactly 20 back steps after 25 pushes, then no more (AC11)', () => {
    let h = start(0);
    for (let i = 1; i <= 25; i++) {
      h = push(h, makeLogo(i));
    }

    for (let i = 0; i < 20; i++) {
      h = back(h);
    }

    expect(h.current).toEqual(makeLogo(5));
    expect(h.past).toHaveLength(0);
    expect(back(h)).toEqual(h);
  });

  it('honours a custom cap', () => {
    let h = start(0);
    for (let i = 1; i <= 10; i++) {
      h = push(h, makeLogo(i), 3);
    }

    expect(h.past).toEqual([makeLogo(7), makeLogo(8), makeLogo(9)]);
  });

  it('stays bounded by the default cap over 1000 pushes', () => {
    let h = start(0);
    for (let i = 1; i <= 1000; i++) {
      h = push(h, makeLogo(i));
    }

    expect(h.past).toHaveLength(20);
  });
});

describe('logo-history back', () => {
  it('returns the earlier logo as current and drops the one left (AC10)', () => {
    const h = push(start(0), makeLogo(1));

    const previous = back(h);

    expect(previous.current).toEqual(makeLogo(0));
    expect(previous.past).toEqual([]);
  });

  it('steps back through several logos in reverse order (AC10)', () => {
    let h = start(0);
    for (let i = 1; i <= 3; i++) {
      h = push(h, makeLogo(i));
    }

    h = back(h);
    expect(h.current).toEqual(makeLogo(2));
    h = back(h);
    expect(h.current).toEqual(makeLogo(1));
    expect(h.past).toEqual([makeLogo(0)]);
  });

  it('does not mutate its input', () => {
    const input = deepFreeze(push(start(0), makeLogo(1)));
    const snapshot = structuredClone(input);

    expect(() => back(input)).not.toThrow();
    expect(input).toEqual(snapshot);
  });

  it('is a no-op returning the same state when past is empty (AC11)', () => {
    const input = deepFreeze(start(0));

    const result = back(input);

    expect(result).toBe(input);
  });

  it('keeps the logo that was current as the newest past entry when pushing after back (AC12)', () => {
    let h = start(0);
    h = push(h, makeLogo(1));
    h = push(h, makeLogo(2));
    h = back(h); // current 1, past [0]

    h = push(h, makeLogo(3));

    expect(h.current).toEqual(makeLogo(3));
    expect(h.past).toEqual([makeLogo(0), makeLogo(1)]);
    expect(back(h).current).toEqual(makeLogo(1));
  });
});
