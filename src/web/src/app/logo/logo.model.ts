export interface Circle {
  kind: 'circle';
  cx: number;
  cy: number;
  r: number;
  fill: string;
}

export interface Rect {
  kind: 'rect';
  x: number;
  y: number;
  width: number;
  height: number;
  rx: number;
  fill: string;
  rotate: number;
}

export interface Polygon {
  kind: 'polygon';
  points: string;
  fill: string;
}

export type Shape = Circle | Rect | Polygon;

export interface Logo {
  name: string;
  background: string;
  shapes: Shape[];
  plate: string;
  textColor: string;
  fontSize: number;
}

export const VIEW_BOX = '0 0 512 512';

/** Plate geometry and text anchor in viewBox units; shared by the inline SVG and the export. */
export const PLATE_Y = 360;
export const PLATE_HEIGHT = 104;
export const TEXT_X = 256;
export const TEXT_Y = 412;
/** System font stack, no web font. */
export const FONT_STACK =
  "system-ui, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
