import { contrastRatio, hslToHex, pickTextColor } from './color';
import { Logo, Shape, VIEW_BOX } from './logo.model';
import { generateName } from './name';
import { createRng } from './random';

export { VIEW_BOX };

const HEX = /^#[0-9a-f]{6}$/;
const NAME_PATTERN = /^[A-Z][a-z]{1,11} [A-Z][a-z]{1,11}$/;
const POINTS_CHARS = /^[0-9., -]+$/;
const POINTS_PATTERN = /^-?\d+(\.\d+)?,-?\d+(\.\d+)?( -?\d+(\.\d+)?,-?\d+(\.\d+)?){2,}$/;
const MIN_CONTRAST = 4.5;
const BOX = 512;
const MAX_NAME_LENGTH = 25;
/** Rough average glyph width in em; keeps a 25 character name inside the view box. */
const AVG_CHAR_EM = 0.6;
const MAX_FONT_SIZE = BOX / (AVG_CHAR_EM * MAX_NAME_LENGTH);
/** Shapes may lie partly outside the view box, but within this margin. */
const COORD_MIN = -BOX;
const COORD_MAX = BOX * 2;

/** Stable string identity of a logo, used to detect duplicates. */
export function logoKey(logo: Logo): string {
  return JSON.stringify(logo);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isColor(value: unknown): value is string {
  return typeof value === 'string' && HEX.test(value);
}

function inRange(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= COORD_MIN && value <= COORD_MAX;
}

function isValidShape(value: unknown): value is Shape {
  if (!isRecord(value) || !isColor(value['fill'])) {
    return false;
  }
  switch (value['kind']) {
    case 'circle':
      return inRange(value['cx']) && inRange(value['cy']) && inRange(value['r']) && value['r'] > 0;
    case 'rect':
      return (
        inRange(value['x']) &&
        inRange(value['y']) &&
        inRange(value['width']) &&
        inRange(value['height']) &&
        inRange(value['rx']) &&
        typeof value['rotate'] === 'number' &&
        Number.isFinite(value['rotate']) &&
        value['width'] > 0 &&
        value['height'] > 0
      );
    case 'polygon': {
      const points = value['points'];
      return typeof points === 'string' && POINTS_CHARS.test(points) && POINTS_PATTERN.test(points);
    }
    default:
      return false;
  }
}

/** Strict check of a logo before it is rendered or exported. */
export function isValidLogo(value: unknown): value is Logo {
  if (!isRecord(value)) {
    return false;
  }
  const { name, background, plate, textColor, fontSize, shapes } = value;
  if (typeof name !== 'string' || !NAME_PATTERN.test(name)) {
    return false;
  }
  if (!isColor(background) || !isColor(plate) || !isColor(textColor)) {
    return false;
  }
  if (
    typeof fontSize !== 'number' ||
    !Number.isFinite(fontSize) ||
    fontSize <= 0 ||
    fontSize > MAX_FONT_SIZE
  ) {
    return false;
  }
  if (!Array.isArray(shapes) || shapes.length === 0 || !shapes.every(isValidShape)) {
    return false;
  }
  if (contrastRatio(textColor, plate) < MIN_CONTRAST) {
    return false;
  }
  const fills = new Set<string>([background, plate, ...shapes.map((s: Shape) => s.fill)]);
  return fills.size >= 3;
}

/** Deterministic logo for a seed: the same seed always gives the same logo. */
export function generateLogo(seed: number): Logo {
  const rng = createRng(seed);
  const between = (min: number, max: number): number => min + rng() * (max - min);
  const int = (min: number, max: number): number => Math.floor(between(min, max + 1));
  const round = (n: number): number => Math.round(n);

  const hue = between(0, 360);
  const background = hslToHex(hue, between(45, 80), between(25, 45));
  // Lightness ranges of background, shapes and plate never overlap, so fills stay distinct.
  const plate = hslToHex(hue + 180, between(10, 30), rng() < 0.5 ? between(90, 96) : between(6, 12));

  const shapes: Shape[] = [];
  const count = int(3, 6);
  for (let i = 0; i < count; i++) {
    const fill = hslToHex(hue + between(30, 330), between(55, 90), between(55, 75));
    const kind = int(0, 2);
    if (kind === 0) {
      shapes.push({
        kind: 'circle',
        cx: round(between(80, 432)),
        cy: round(between(60, 300)),
        r: round(between(30, 130)),
        fill,
      });
    } else if (kind === 1) {
      shapes.push({
        kind: 'rect',
        x: round(between(40, 360)),
        y: round(between(40, 260)),
        width: round(between(60, 200)),
        height: round(between(60, 200)),
        rx: round(between(0, 40)),
        fill,
        rotate: round(between(-45, 45)),
      });
    } else {
      const sides = int(3, 6);
      const cx = between(120, 392);
      const cy = between(120, 260);
      const radius = between(50, 130);
      const offset = between(0, Math.PI * 2);
      const points = Array.from({ length: sides }, (_, k) => {
        const angle = offset + (k * Math.PI * 2) / sides;
        return `${round(cx + radius * Math.cos(angle))},${round(cy + radius * Math.sin(angle))}`;
      }).join(' ');
      shapes.push({ kind: 'polygon', points, fill });
    }
  }

  const name = generateName(rng);
  const fontSize = Math.min(34, Math.floor(400 / (name.length * 0.65)));
  return { name, background, shapes, plate, textColor: pickTextColor(plate), fontSize };
}
