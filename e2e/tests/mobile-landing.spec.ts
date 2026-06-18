import { expect, test } from "@playwright/test";

test.describe("landing page mobile (<768px)", () => {
  test("hero email CTA is centered and the page has no horizontal overflow", async ({ page }) => {
    await page.goto("/");

    const viewport = page.viewportSize();
    expect(viewport).not.toBeNull();

    const heroForm = page.locator(".hero-form").first();
    await expect(heroForm).toBeVisible();

    const rect = await heroForm.evaluate((el) => el.getBoundingClientRect());
    const leftGap = rect.left;
    const rightGap = viewport!.width - rect.right;
    expect(Math.abs(leftGap - rightGap)).toBeLessThanOrEqual(2);

    // Regression guard: the infinite bank-logo marquee previously inflated
    // the page width past the viewport, letting mobile browsers zoom out.
    const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(scrollWidth).toBeLessThanOrEqual(viewport!.width);
  });

  test("bank marquee does not overflow the viewport", async ({ page }) => {
    await page.goto("/");

    const marquee = page.locator(".marquee").first();
    await marquee.scrollIntoViewIfNeeded();

    const viewport = page.viewportSize();
    expect(viewport).not.toBeNull();

    const rect = await marquee.evaluate((el) => el.getBoundingClientRect());
    expect(rect.right).toBeLessThanOrEqual(viewport!.width + 1);

    const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(scrollWidth).toBeLessThanOrEqual(viewport!.width);
  });
});
