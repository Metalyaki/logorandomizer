import { DOCUMENT } from '@angular/common';
import { Injectable, inject } from '@angular/core';
import { Logo } from './logo.model';
import { toFileName, toSvgString } from './svg-export';

const SVG_MIME_TYPE = 'image/svg+xml';

/** Starts a browser download of the logo as an SVG file. Never throws and does not touch the store. */
@Injectable({ providedIn: 'root' })
export class SvgDownload {
  private readonly document = inject(DOCUMENT);

  download(logo: Logo): void {
    let url: string;
    try {
      const blob = new Blob([toSvgString(logo)], { type: SVG_MIME_TYPE });
      url = URL.createObjectURL(blob);
    } catch {
      return;
    }

    const anchor = this.document.createElement('a');
    anchor.href = url;
    anchor.download = toFileName(logo.name);
    anchor.hidden = true;

    try {
      this.document.body.appendChild(anchor);
      anchor.click();
    } catch {
      // Download could not start; cleanup below still runs.
    } finally {
      setTimeout(() => {
        try {
          URL.revokeObjectURL(url);
        } catch {
          // Nothing left to release.
        }
        anchor.remove();
      }, 0);
    }
  }
}
