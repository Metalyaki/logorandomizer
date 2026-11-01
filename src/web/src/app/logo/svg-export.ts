import { Logo, Shape, VIEW_BOX } from './logo.model';

const SVG_NS = 'http://www.w3.org/2000/svg';
const BOX = 512;
const PLATE_Y = 360;
const PLATE_HEIGHT = 104;
const MAX_BASE_LENGTH = 40;
const FALLBACK_FILE_NAME = 'logo.svg';
/** System font stack, no web font. Escaped on output, so the quotes stay valid XML. */
const FONT_STACK = "system-ui, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";

const XML_ESCAPES: Record<string, string> = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&apos;',
};

/** Escapes text for use as XML text content or inside a quoted attribute value. */
function esc(value: string | number): string {
  return String(value).replace(/[&<>"']/g, (ch) => XML_ESCAPES[ch]);
}

function shapeToSvg(shape: Shape): string {
  switch (shape.kind) {
    case 'circle':
      return `<circle cx="${esc(shape.cx)}" cy="${esc(shape.cy)}" r="${esc(shape.r)}" fill="${esc(shape.fill)}"/>`;
    case 'rect': {
      const cx = shape.x + shape.width / 2;
      const cy = shape.y + shape.height / 2;
      const transform =
        shape.rotate === 0 ? '' : ` transform="rotate(${esc(shape.rotate)} ${esc(cx)} ${esc(cy)})"`;
      return `<rect x="${esc(shape.x)}" y="${esc(shape.y)}" width="${esc(shape.width)}" height="${esc(shape.height)}" rx="${esc(shape.rx)}" fill="${esc(shape.fill)}"${transform}/>`;
    }
    case 'polygon':
      return `<polygon points="${esc(shape.points)}" fill="${esc(shape.fill)}"/>`;
    default: {
      const unreachable: never = shape;
      return unreachable;
    }
  }
}

/** Builds a self contained SVG document from a fixed set of elements; all values are XML-escaped. */
export function toSvgString(logo: Logo): string {
  const shapes = logo.shapes.map(shapeToSvg).join('');
  const textY = PLATE_Y + PLATE_HEIGHT / 2;
  return (
    `<svg xmlns="${SVG_NS}" viewBox="${VIEW_BOX}" width="${BOX}" height="${BOX}">` +
    `<rect x="0" y="0" width="${BOX}" height="${BOX}" fill="${esc(logo.background)}"/>` +
    `<g>${shapes}</g>` +
    `<rect x="0" y="${PLATE_Y}" width="${BOX}" height="${PLATE_HEIGHT}" fill="${esc(logo.plate)}"/>` +
    `<text x="${BOX / 2}" y="${textY}" text-anchor="middle" dominant-baseline="central" font-family="${esc(FONT_STACK)}" font-weight="700" font-size="${esc(logo.fontSize)}" fill="${esc(logo.textColor)}">${esc(logo.name)}</text>` +
    `</svg>`
  );
}

/** Turns a logo name into a safe download file name: a-z, 0-9 and hyphens, at most 40 characters. */
export function toFileName(name: string): string {
  const base = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, MAX_BASE_LENGTH)
    .replace(/-+$/g, '');
  return base === '' ? FALLBACK_FILE_NAME : `${base}.svg`;
}
