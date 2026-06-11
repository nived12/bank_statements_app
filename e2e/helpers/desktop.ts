import { type Locator, type Page } from "@playwright/test";

/**
 * Visible desktop parity shells (`hidden md:block`) at the default Playwright
 * viewport (1280×720). Mobile markup is `block md:hidden` and is not matched.
 */
export function desktopView(page: Page): Locator {
  return page.locator("div.hidden.md\\:block").locator("visible=true");
}

/** Desktop new/edit form wrapper located by its Stimulus controller. */
export function desktopFormShell(page: Page, stimulusController: string): Locator {
  return page
    .locator(`div.hidden.md\\:block[data-controller*="${stimulusController}"]`)
    .locator("visible=true")
    .first();
}

/** Settings desktop column (`max-w-2xl` shell). */
export function desktopSettings(page: Page): Locator {
  return page.locator("div.hidden.md\\:block.max-w-2xl").locator("visible=true").first();
}

/** Transactions sub-nav tab strip (Recurrentes lives here on desktop). */
export function desktopRecurringTab(page: Page): Locator {
  return page.locator('div.hidden.md\\:block.border-b a[href="/recurring"]').locator("visible=true").first();
}

/** Desktop recurring show page shell. */
export function desktopRecurringShow(page: Page): Locator {
  return page
    .locator("div.hidden.md\\:block.min-h-screen")
    .locator("visible=true")
    .first();
}

/** Desktop sidebar sign-out control (hidden on mobile). */
export function desktopSignOutButton(page: Page): Locator {
  return page.locator('aside.hidden.md\\:flex form[action="/session"] button[type="submit"]');
}
