import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { Logo, Rect } from './logo.model';

/** Renders a logo as an inline SVG with Angular bindings only; mirrors toSvgString in svg-export.ts. */
@Component({
  selector: 'app-logo-svg',
  templateUrl: './logo-svg.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LogoSvg {
  readonly logo = input.required<Logo>();

  /** rotate(...) transform around the rect centre, or null (attribute omitted) when not rotated. */
  protected rotation(shape: Rect): string | null {
    if (shape.rotate === 0) {
      return null;
    }
    const cx = shape.x + shape.width / 2;
    const cy = shape.y + shape.height / 2;
    return `rotate(${shape.rotate} ${cx} ${cy})`;
  }
}
