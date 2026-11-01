import { test, expect } from '@playwright/test';
import { request } from 'node:http';

/** Sends a raw request target without any client-side path normalization. */
function raw(baseURL: string, target: string): Promise<{ status: number; body: string }> {
  const { hostname, port } = new URL(baseURL);
  return new Promise((resolve, reject) => {
    const req = request({ hostname, port, path: target, method: 'GET' }, (res) => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (chunk: string) => (body += chunk));
      res.on('end', () => resolve({ status: res.statusCode ?? 0, body }));
    });
    req.on('error', reject);
    req.end();
  });
}

test.describe('serve.mjs path handling', () => {
  test('serves the app', async ({ baseURL }) => {
    const res = await raw(baseURL as string, '/');
    expect(res.status).toBe(200);
    expect(res.body).toContain('app-root');
  });

  for (const target of [
    '/../package.json',
    '/../../package.json',
    '/%2e%2e/package.json',
    '/%2E%2E%2Fpackage.json',
    '/a/../../package.json',
    '/..\\package.json',
    '/%5c..%5cpackage.json',
    '/index.html%00.js',
    '/%zz',
  ]) {
    test(`refuses ${target}`, async ({ baseURL }) => {
      const res = await raw(baseURL as string, target);
      expect(res.status).toBe(400);
      expect(res.body).not.toContain('"name"');
    });
  }
});
