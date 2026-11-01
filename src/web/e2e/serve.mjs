// Static server for the built app that applies the real security headers from
// staticwebapp.config.json, so e2e tests run under the deployed CSP (SR6, SR10).
import { createServer } from 'node:http';
import { readFileSync, statSync, createReadStream } from 'node:fs';
import { resolve, sep, extname, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../dist/web/browser');
const port = Number(process.env.PORT ?? 4300);

const config = JSON.parse(readFileSync(resolve(root, 'staticwebapp.config.json'), 'utf8'));
const securityHeaders = config.globalHeaders;

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
  '.map': 'application/json; charset=utf-8',
};

function send(res, status, body) {
  res.writeHead(status, { ...securityHeaders, 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(body);
}

/** Maps a raw request target to a file inside root, or null when it must be refused. */
function resolveRequest(rawTarget) {
  const rawPath = rawTarget.split(/[?#]/)[0];
  let decoded;
  try {
    decoded = decodeURIComponent(rawPath);
  } catch {
    return null;
  }
  if (decoded.includes('\0') || decoded.includes('\\') || !decoded.startsWith('/')) return null;
  if (decoded.split('/').some((segment) => segment === '..')) return null;
  const relative = decoded.endsWith('/') ? decoded + 'index.html' : decoded;
  const file = resolve(root, '.' + relative);
  if (file !== root && !file.startsWith(root + sep)) return null;
  return file;
}

const server = createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') return send(res, 405, 'Method not allowed');
  const file = resolveRequest(req.url ?? '/');
  if (!file) return send(res, 400, 'Bad request');
  let stat;
  try {
    stat = statSync(file);
  } catch {
    return send(res, 404, 'Not found');
  }
  if (!stat.isFile()) return send(res, 404, 'Not found');
  res.writeHead(200, {
    ...securityHeaders,
    'Content-Type': types[extname(file)] ?? 'application/octet-stream',
    'Content-Length': stat.size,
    'Cache-Control': 'no-store',
  });
  if (req.method === 'HEAD') return res.end();
  createReadStream(file).pipe(res);
});

server.listen(port, '127.0.0.1', () => {
  console.log(`serving ${root} on http://127.0.0.1:${port}`);
});
