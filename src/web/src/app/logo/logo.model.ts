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
