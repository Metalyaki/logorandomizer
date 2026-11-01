import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { generateLogo, logoKey } from './logo-generator';
import { LogoStore } from './logo-store';
import { SvgDownload } from './svg-download';
import { toFileName, toSvgString } from './svg-export';

const BLOB_URL = 'blob:http://localhost/test-object-url';

describe('SvgDownload', () => {
  const logo = generateLogo(7);
  let createObjectURL: ReturnType<typeof vi.fn>;
  let revokeObjectURL: ReturnType<typeof vi.fn>;
  let clicked: HTMLAnchorElement[];
  let attachedDuringClick: boolean[];
  let clickImpl: (anchor: HTMLAnchorElement) => void;
  let originalCreate: unknown;
  let originalRevoke: unknown;

  beforeEach(() => {
    vi.useFakeTimers();
    clicked = [];
    attachedDuringClick = [];
    clickImpl = () => undefined;

    // Browser edge: object URLs and the anchor click (a real click would start a download).
    originalCreate = (URL as unknown as Record<string, unknown>)['createObjectURL'];
    originalRevoke = (URL as unknown as Record<string, unknown>)['revokeObjectURL'];
    createObjectURL = vi.fn(() => BLOB_URL);
    revokeObjectURL = vi.fn();
    Object.defineProperty(URL, 'createObjectURL', {
      value: createObjectURL,
      configurable: true,
      writable: true,
    });
    Object.defineProperty(URL, 'revokeObjectURL', {
      value: revokeObjectURL,
      configurable: true,
      writable: true,
    });
    vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (
      this: HTMLAnchorElement,
    ) {
      clicked.push(this);
      attachedDuringClick.push(document.body.contains(this));
      clickImpl(this);
    });
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
    Object.defineProperty(URL, 'createObjectURL', {
      value: originalCreate,
      configurable: true,
      writable: true,
    });
    Object.defineProperty(URL, 'revokeObjectURL', {
      value: originalRevoke,
      configurable: true,
      writable: true,
    });
    document.querySelectorAll('a[download]').forEach((a) => a.remove());
  });

  function service(): SvgDownload {
    return TestBed.inject(SvgDownload);
  }

  describe('file content (AC14)', () => {
    it('creates one Blob with MIME type image/svg+xml', () => {
      service().download(logo);

      expect(createObjectURL).toHaveBeenCalledTimes(1);
      const blob = createObjectURL.mock.calls[0][0] as Blob;
      expect(blob).toBeInstanceOf(Blob);
      expect(blob.type).toBe('image/svg+xml');
    });

    it('puts exactly toSvgString(logo) in the Blob', async () => {
      service().download(logo);

      const blob = createObjectURL.mock.calls[0][0] as Blob;
      expect(await blob.text()).toBe(toSvgString(logo));
    });
  });

  describe('file name (AC15)', () => {
    it('sets the anchor download attribute to toFileName(name) and points it at the object URL', () => {
      service().download(logo);

      expect(clicked).toHaveLength(1);
      expect(clicked[0].download).toBe(toFileName(logo.name));
      expect(clicked[0].getAttribute('href')).toBe(BLOB_URL);
    });
  });

  describe('cleanup (AC17)', () => {
    it('clicks the anchor while it is attached to the document', () => {
      service().download(logo);

      expect(attachedDuringClick).toEqual([true]);
    });

    it('revokes the object URL and removes the anchor only after the timer', () => {
      service().download(logo);

      expect(revokeObjectURL).not.toHaveBeenCalled();
      expect(document.body.contains(clicked[0])).toBe(true);

      vi.runAllTimers();

      expect(revokeObjectURL).toHaveBeenCalledTimes(1);
      expect(revokeObjectURL).toHaveBeenCalledWith(BLOB_URL);
      expect(document.body.contains(clicked[0])).toBe(false);
    });

    it('leaves the store state unchanged', () => {
      const store = TestBed.inject(LogoStore);
      const current = store.current();
      const history = store.history();
      const canGoBack = store.canGoBack();

      service().download(store.current());
      vi.runAllTimers();

      expect(logoKey(store.current())).toBe(logoKey(current));
      expect(store.history()).toEqual(history);
      expect(store.canGoBack()).toBe(canGoBack);
    });
  });

  describe('failures', () => {
    it('does not throw when createObjectURL throws, and leaves no anchor behind', () => {
      createObjectURL.mockImplementation(() => {
        throw new Error('boom');
      });

      expect(() => service().download(logo)).not.toThrow();
      vi.runAllTimers();

      expect(clicked).toHaveLength(0);
      expect(document.querySelector('a[download]')).toBeNull();
    });

    it('does not throw when click throws, and still removes the anchor and revokes the URL', () => {
      clickImpl = () => {
        throw new Error('blocked');
      };

      expect(() => service().download(logo)).not.toThrow();
      vi.runAllTimers();

      expect(revokeObjectURL).toHaveBeenCalledWith(BLOB_URL);
      expect(document.body.contains(clicked[0])).toBe(false);
    });
  });
});
