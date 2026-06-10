import { expect, type Locator, type Page } from "@playwright/test";

/**
 * Visible mobile parity shells (`block md:hidden`) at iPhone-class viewports.
 * Desktop markup is `hidden md:block` and must not be interacted with.
 */
export function mobileView(page: Page): Locator {
  return page.locator("div.block.md\\:hidden").locator("visible=true");
}

/** Mobile form page wrapper located by Stimulus controller when present. */
export function mobileFormShell(page: Page, stimulusController?: string): Locator {
  const base = "div.block.md\\:hidden.mobile-form-page";
  const selector = stimulusController
    ? `${base}[data-controller*="${stimulusController}"]`
    : base;
  return page.locator(selector).locator("visible=true").first();
}

/** Sticky mobile form save footer (Crear / Guardar). */
export function mobileFormFooter(page: Page): Locator {
  return page.locator("div.mobile-form-footer.md\\:hidden").locator("visible=true").first();
}

/** Bottom tab bar inside the mobile app shell. */
export function mobileBottomNav(page: Page): Locator {
  return page.locator(".mobile-bottom-nav-shell nav.mobile-bottom-nav").first();
}

export function isPricingGate(page: Page): boolean {
  return /\/pricing/.test(page.url());
}

/** Assert the bottom nav sits flush with the viewport bottom (flex-column shell). */
export async function expectBottomNavPinnedToViewport(page: Page): Promise<void> {
  const nav = mobileBottomNav(page);
  await expect(nav).toBeVisible();

  const viewport = page.viewportSize();
  expect(viewport).not.toBeNull();

  const rect = await nav.evaluate((el) => el.getBoundingClientRect());
  // Allow safe-area padding below the 49px tab bar (env(safe-area-inset-bottom)).
  const safeAreaSlack = 40;
  expect(rect.bottom).toBeGreaterThanOrEqual(viewport!.height - safeAreaSlack);
  expect(rect.bottom).toBeLessThanOrEqual(viewport!.height + 34);
}
