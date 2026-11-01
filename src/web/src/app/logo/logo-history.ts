import type { Logo } from './logo.model';

export interface History {
  current: Logo;
  past: readonly Logo[];
}

export function push(history: History, logo: Logo, cap = 20): History {
  return { current: logo, past: [...history.past, history.current].slice(-cap) };
}

export function back(history: History): History {
  if (history.past.length === 0) {
    return history;
  }
  return { current: history.past[history.past.length - 1], past: history.past.slice(0, -1) };
}
