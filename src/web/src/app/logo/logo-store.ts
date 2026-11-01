import { computed, inject, Injectable, InjectionToken, signal } from '@angular/core';
import { generateLogo, isValidLogo, logoKey } from './logo-generator';
import { back, type History, push } from './logo-history';
import type { Logo } from './logo.model';
import { SEED_SOURCE } from './random';

/** Creates a logo from a seed; tests replace it with a fake. */
export const GENERATE_LOGO = new InjectionToken<(seed: number) => Logo>('GENERATE_LOGO', {
  providedIn: 'root',
  factory: () => generateLogo,
});

/** How many fresh seeds to try when a seed gives the logo that is already shown. */
const MAX_ATTEMPTS = 20;

@Injectable({ providedIn: 'root' })
export class LogoStore {
  private readonly nextSeed = inject(SEED_SOURCE);
  private readonly generate = inject(GENERATE_LOGO);
  private readonly state = signal<History>({ current: this.generate(this.nextSeed()), past: [] });

  readonly history = this.state.asReadonly();
  readonly current = computed(() => this.state().current);
  readonly canGoBack = computed(() => this.state().past.length > 0);

  /** Shows a new valid logo that differs from the current one; keeps the state if none can be made. */
  randomize(): void {
    const shown = logoKey(this.state().current);
    for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
      let logo: Logo;
      try {
        logo = this.generate(this.nextSeed());
      } catch {
        return;
      }
      if (!isValidLogo(logo)) {
        return;
      }
      if (logoKey(logo) !== shown) {
        this.state.update((history) => push(history, logo));
        return;
      }
    }
  }

  /** Returns to the previous logo; does nothing when there is none. */
  previous(): void {
    this.state.update((history) => back(history));
  }
}
