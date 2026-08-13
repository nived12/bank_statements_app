import { expect, type Locator, type Page } from "@playwright/test";

/**
 * Visible mobile parity shells (`block md:hidden`) at iPhone-class viewports.
 * Desktop markup is `hidden md:block` and must not be interacted with.
 */
export function mobileView(page: Page): Locator {
  return page.locator("div.block.md\\:hidden").locator("visible=true");
}

/** Non-form mobile screens (dashboard, finances, accounts list). */
export function mobilePageShell(page: Page): Locator {
  return page.locator("div.block.md\\:hidden.mobile-app-screen").locator("visible=true").first();
}

/** Finances combined screen with segmented savings/debts/goals tabs. */
export function mobileFinancesShell(page: Page): Locator {
  return page
    .locator('div.block.md\\:hidden[data-controller*="segmented-control"]')
    .locator("visible=true")
    .first();
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

/**
 * Navigate to a path and return false when subscription gate redirects to /pricing.
 * Caller should `test.skip()` when this returns false.
 */
export async function gotoMobile(page: Page, path: string): Promise<boolean> {
  await page.goto(path);
  return !isPricingGate(page);
}

/** Assert dual-DOM pages keep the desktop Stimulus shell hidden at mobile viewport. */
export async function expectDesktopShellHidden(page: Page, stimulusController: string): Promise<void> {
  await expect(
    page.locator(`div.hidden.md\\:block[data-controller*="${stimulusController}"]`)
  ).toBeHidden();
}

/** Assert the bottom nav sits flush with the viewport bottom (flex-column shell). */
export async function expectBottomNavPinnedToViewport(page: Page): Promise<void> {
  const nav = mobileBottomNav(page);
  await expect(nav).toBeVisible();

  const viewport = page.viewportSize();
  expect(viewport).not.toBeNull();

  // After a Turbo navigation the `h-dvh` shell can resolve to 0 height for a
  // frame, collapsing the nav box. Keep the polled measurement and assert on
  // that — re-measuring after the poll lets it collapse again in between.
  let bottom = 0;
  await expect
    .poll(
      async () => {
        bottom = await nav.evaluate((el) => el.getBoundingClientRect().bottom);
        return bottom;
      },
      { timeout: 5_000 }
    )
    .toBeGreaterThan(0);

  // Allow safe-area padding below the 49px tab bar (env(safe-area-inset-bottom)).
  const safeAreaSlack = 40;
  expect(bottom).toBeGreaterThanOrEqual(viewport!.height - safeAreaSlack);
  expect(bottom).toBeLessThanOrEqual(viewport!.height + 34);
}
