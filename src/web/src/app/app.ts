import { ChangeDetectionStrategy, Component, ElementRef, inject, viewChild } from '@angular/core';
import { LogoStore } from './logo/logo-store';
import { LogoSvg } from './logo/logo-svg';
import { SvgDownload } from './logo/svg-download';

@Component({
  selector: 'app-root',
  imports: [LogoSvg],
  templateUrl: './app.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class App {
  protected readonly store = inject(LogoStore);
  private readonly svgDownload = inject(SvgDownload);
  private readonly randomizeButton = viewChild.required<ElementRef<HTMLButtonElement>>('randomizeButton');

  protected randomize(): void {
    this.store.randomize();
  }

  protected previous(): void {
    this.store.previous();
    // A disabled button loses keyboard focus, so hand it to Randomize.
    if (!this.store.canGoBack()) {
      this.randomizeButton().nativeElement.focus();
    }
  }

  protected download(): void {
    this.svgDownload.download(this.store.current());
  }
}
