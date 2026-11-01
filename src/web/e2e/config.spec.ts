import { test, expect } from '@playwright/test';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const sourcePath = resolve(__dirname, '../public/staticwebapp.config.json');
const builtPath = resolve(__dirname, '../dist/web/browser/staticwebapp.config.json');

interface SwaConfig {
  globalHeaders: Record<string, string>;
}

const config = JSON.parse(readFileSync(sourcePath, 'utf8')) as SwaConfig;
const headers = config.globalHeaders;

function parseCsp(csp: string): Map<string, string[]> {
  const map = new Map<string, string[]>();
  for (const part of csp.split(';')) {
    const tokens = part.trim().split(/\s+/).filter(Boolean);
    if (tokens.length === 0) continue;
    const [name, ...values] = tokens;
    const key = name.toLowerCase();
    if (map.has(key)) throw new Error(`Duplicate CSP directive: ${key}`);
    map.set(key, values);
  }
  return map;
}

const expectedCsp: Record<string, string[]> = {
  'default-src': ["'self'"],
  'script-src': ["'self'"],
  'style-src': ["'self'"],
  'img-src': ["'self'"],
  'font-src': ["'self'"],
  'connect-src': ["'self'"],
  'object-src': ["'none'"],
  'base-uri': ["'none'"],
  'form-action': ["'none'"],
  'frame-ancestors': ["'none'"],
};

test.describe('staticwebapp.config.json (SR6, SR7)', () => {
  const csp = parseCsp(headers['Content-Security-Policy']);

  test('CSP has exactly the expected directives and values', () => {
    expect(Object.fromEntries(csp)).toEqual(expectedCsp);
  });

  test('CSP rejects duplicate directives', () => {
    expect(() => parseCsp("script-src 'self'; script-src 'unsafe-inline'")).toThrow(/Duplicate/);
  });

  test('script-src allows no unsafe sources', () => {
    const values = csp.get('script-src') ?? [];
    for (const bad of ["'unsafe-inline'", "'unsafe-eval'", 'data:', 'blob:', '*', 'http:']) {
      expect(values).not.toContain(bad);
    }
  });

  test('no directive allows unsafe keywords, wildcards or remote origins', () => {
    for (const [name, values] of csp) {
      for (const value of values) {
        expect(value, `${name}: ${value}`).not.toBe("'unsafe-inline'");
        expect(value, `${name}: ${value}`).not.toBe("'unsafe-eval'");
        expect(value, `${name}: ${value}`).not.toBe('*');
        expect(value, `${name}: ${value}`).not.toMatch(/^(https?:)?\/\//i);
      }
    }
  });

  test('security headers match SR7 exactly', () => {
    expect(headers['X-Content-Type-Options']).toBe('nosniff');
    expect(headers['Referrer-Policy']).toBe('no-referrer');
    expect(headers['Permissions-Policy']).toBe('camera=(), microphone=(), geolocation=()');
  });

  test('only the expected headers are set', () => {
    expect(Object.keys(headers).sort()).toEqual(
      [
        'Content-Security-Policy',
        'Permissions-Policy',
        'Referrer-Policy',
        'X-Content-Type-Options',
      ].sort(),
    );
  });

  test('build output copy is byte-equal to the source', () => {
    test.skip(!existsSync(builtPath), 'dist is missing: run npm run build');
    expect(readFileSync(builtPath).equals(readFileSync(sourcePath))).toBe(true);
  });
});
