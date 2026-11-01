import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { FONT_STACK, Logo, PLATE_HEIGHT, PLATE_Y, Rect, TEXT_X, TEXT_Y } from './logo.model';

/** Renders a logo as an inline SVG with Angular bindings only; mirrors toSvgString in svg-export.ts. */
@Component({
  selector: 'app-logo-svg',
  templateUrl: './logo-svg.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LogoSvg {
  readonly logo = input.required<Logo>();

  protected readonly plateY = PLATE_Y;
  protected readonly plateHeight = PLATE_HEIGHT;
  protected readonly textX = TEXT_X;
  protected readonly textY = TEXT_Y;
  protected readonly fontStack = FONT_STACK;

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
