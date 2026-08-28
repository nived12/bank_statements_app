import { expect, test } from "@playwright/test";
import { AUTH_FILE } from "../helpers/auth";
import { desktopView } from "../helpers/desktop";

test.use({ storageState: AUTH_FILE });

// Both live previews read the balance input by name. When that field was renamed
// current_amount -> opening_balance, querySelector started returning null and both
// computations silently aborted — the panel rendered but never produced a number,
// with nothing in the console to show for it.

async function openAdvanced(page: import("@playwright/test").Page) {
  const form = desktopView(page);
  const toggle = form.getByRole("button", { name: /Configuración Avanzada/i }).first();
  if (await toggle.isVisible()) await toggle.click();
  await expect(form.getByRole("heading", { name: /Seguimiento de Contribuciones/i })).toBeVisible();
}

async function chooseMode(page: import("@playwright/test").Page, label: RegExp) {
  const form = desktopView(page);
  await form.locator("[data-contribution-mode-target='modeButton']").click();
  await form.locator("[data-mode]").filter({ hasText: label }).click();
}

test.describe("Contribution tracking previews", () => {
  test("fixed mode suggests a target date from the amount entered", async ({ page }) => {
    await page.goto("/savings/new");
    const form = desktopView(page);
    await form.locator("#saving_name").fill("E2E Contribution Fixed");
    await form.locator("#saving_target_amount").fill("12000");
    await form.locator("#saving_opening_balance").fill("2000");

    await openAdvanced(page);
    await chooseMode(page, /Cantidad fija por período/i);
    await form.locator("#saving_target_contribution_amount").fill("1000");

    // 10,000 remaining at 1,000 per period = 10 periods, so a real date must appear
    // where the placeholder prompt used to sit.
    const suggested = form.locator("[data-contribution-mode-target='suggestedDateDisplay']");
    await expect(suggested).toHaveValue(/\d{4}/, { timeout: 10_000 });
  });

  test("calculated mode divides the remainder over the target date", async ({ page }) => {
    await page.goto("/savings/new");
    const form = desktopView(page);
    await form.locator("#saving_name").fill("E2E Contribution Calculated");
    await form.locator("#saving_target_amount").fill("12000");
    await form.locator("#saving_opening_balance").fill("2000");
    const target = new Date();
    target.setMonth(target.getMonth() + 10);
    await form.locator("#saving_target_date").fill(target.toISOString().slice(0, 10));

    await openAdvanced(page);
    await chooseMode(page, /Calculado desde la fecha/i);

    // 10,000 remaining over 10 months is 1,000 a month — the number itself is the
    // assertion, since "not zero" would pass on any garbage the preview produced.
    const amount = form.locator("[data-contribution-mode-target='calculatedAmountValue']");
    await expect(amount).toContainText(/1,000\.00/, { timeout: 10_000 });
  });
});
