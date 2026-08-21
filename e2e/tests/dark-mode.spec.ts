import { expect, test, type Page } from "@playwright/test";

test.use({ storageState: "e2e/.auth/user.json" });

// Force dark mode before any page script runs. The layout's inline boot script
// reads localStorage["vittio-theme"] and stamps data-theme on <html>, so seeding
// it here makes every navigation render in dark mode.
test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    window.localStorage.setItem("vittio-theme", "dark");
  });
});

// Smoke coverage for the dark-mode contrast fixes: we can't meaningfully assert
// pixel-level contrast, so instead we guard against regressions where a page
// fails to render or throws while in dark mode.
async function expectRendersInDarkMode(page: Page, path: string) {
  const pageErrors: Error[] = [];
  page.on("pageerror", (error) => pageErrors.push(error));

  await page.goto(path);

  // Boot script applied the dark theme.
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");

  // The page actually rendered content, not a blank/error shell.
  await expect(page.locator("main, form").first()).toBeVisible();

  // No uncaught JS exceptions while rendering in dark mode.
  expect(pageErrors, `Uncaught errors on ${path}: ${pageErrors.map((e) => e.message).join("; ")}`).toEqual([]);
}

test("dashboard renders in dark mode", async ({ page }) => {
  await expectRendersInDarkMode(page, "/");
});

test("bank account form renders in dark mode", async ({ page }) => {
  await expectRendersInDarkMode(page, "/bank_accounts/new");
});

test("savings form (contribution mode) renders in dark mode", async ({ page }) => {
  await expectRendersInDarkMode(page, "/savings/new");
});

test("debt form (payment mode) renders in dark mode", async ({ page }) => {
  await expectRendersInDarkMode(page, "/debts/new");
});

// The bug this guards: the multi-select summary got `text-slate-900` with no dark
// variant, rendering near-black on a near-black button — 1.22:1, invisible until a
// hover lightened the background. Smoke tests cannot see that, so measure the real
// contrast. Canvas rasterises any colour space (the app uses oklch) to sRGB bytes.
test("multi-select summary stays readable in dark mode", async ({ page }) => {
  await page.goto("/debts/new");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");

  const desktop = page.locator("div.hidden.md\\:block").filter({ visible: true });
  const multiSelect = desktop.locator('[data-controller="multi-select"]').first();

  await multiSelect.locator('button[data-multi-select-target="button"]').click();
  await multiSelect.locator('input[data-multi-select-target="checkbox"]').first().check();

  const summary = multiSelect.locator('[data-multi-select-target="summary"]');
  await expect(summary).not.toBeEmpty();

  const ratio = await summary.evaluate((el) => {
    const canvas = document.createElement("canvas");
    canvas.width = canvas.height = 1;
    const ctx = canvas.getContext("2d", { willReadFrequently: true })!;
    const toRgb = (css: string) => {
      ctx.clearRect(0, 0, 1, 1);
      ctx.fillStyle = css;
      ctx.fillRect(0, 0, 1, 1);
      return Array.from(ctx.getImageData(0, 0, 1, 1).data).slice(0, 3);
    };
    const luminance = (rgb: number[]) => {
      const s = rgb.map((v) => {
        const x = v / 255;
        return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
      });
      return 0.2126 * s[0] + 0.7152 * s[1] + 0.0722 * s[2];
    };
    const button = el.closest("button")!;
    const [hi, lo] = [
      luminance(toRgb(getComputedStyle(el).color)),
      luminance(toRgb(getComputedStyle(button).backgroundColor)),
    ].sort((a, b) => b - a);
    return (hi + 0.05) / (lo + 0.05);
  });

  // WCAG AA for normal text.
  expect(ratio).toBeGreaterThanOrEqual(4.5);
});
