import { expect, test } from "@playwright/test";
import { AUTH_FILE } from "../helpers/auth";
import { desktopView } from "../helpers/desktop";

test.use({ storageState: AUTH_FILE });

// The seeded e2e user only has "active" savings/debts (see db/seeds/playwright.rb),
// so the "paused" tab is empty and renders the starter-template picker.

test.describe("Starter templates — savings", () => {
  test("empty state offers templates; picking one pre-fills the new form", async ({ page }) => {
    await page.goto("/savings?status=paused");

    const picker = desktopView(page).getByRole("link", { name: /Fondo de Emergencia/i });
    await expect(picker).toBeVisible();
    await expect(desktopView(page).getByText(/Aparta de 3 a 6 meses de gastos/i)).toBeVisible();

    await picker.click();

    await expect(page).toHaveURL(/\/savings\/new\?template=emergency_fund/);
    await expect(desktopView(page).locator("#saving_name")).toHaveValue("Fondo de Emergencia");
    // The currency-input Stimulus controller reformats "10000.0" to "10,000" on render.
    await expect(desktopView(page).locator("#saving_target_amount")).toHaveValue(/^10,000(\.0+)?$/);
    // The matching category ("Fondo de Emergencia") is pre-selected.
    const categoryCheckbox = desktopView(page)
      .locator("label", { hasText: "Fondo de Emergencia" })
      .locator("input[type='checkbox']");
    await expect(categoryCheckbox).toBeChecked();
  });

  test("creating from a template saves the user's edited values", async ({ page }) => {
    await page.goto("/savings/new?template=emergency_fund");

    const form = desktopView(page);
    await form.locator("#saving_target_amount").fill("12345");
    await form.getByRole("button", { name: /Crear Ahorro/i }).click();

    await page.waitForURL(/\/savings\/\d+/, { timeout: 15_000 });
    await expect(desktopView(page).getByText(/Fondo de Emergencia/i).first()).toBeVisible();
    await expect(desktopView(page).getByText(/12,345|12345/).first()).toBeVisible();
  });
});

test.describe("Starter templates — debts", () => {
  test("empty state offers templates; picking one pre-fills the new form", async ({ page }) => {
    await page.goto("/debts?status=paused");

    const picker = desktopView(page).getByRole("link", { name: /Tarjeta de Crédito/i });
    await expect(picker).toBeVisible();

    await picker.click();

    await expect(page).toHaveURL(/\/debts\/new\?template=credit_card/);
    await expect(desktopView(page).locator("#debt_name")).toHaveValue("Tarjeta de Crédito");
    await expect(desktopView(page).locator("#debt_interest_rate")).toHaveValue("18.5");
    // Balances are personal — never pre-filled from a template.
    await expect(desktopView(page).locator("#debt_original_amount")).toHaveValue("");
    // The matching category ("Tarjetas de Crédito") is pre-selected.
    const categoryCheckbox = desktopView(page)
      .locator("label", { hasText: "Tarjetas de Crédito" })
      .locator("input[type='checkbox']");
    await expect(categoryCheckbox).toBeChecked();
  });

  test("category multi-select supports search filtering", async ({ page }) => {
    await page.goto("/debts/new?template=credit_card");

    const form = desktopView(page);
    // Open the categories multi-select.
    await form.getByRole("button").filter({ hasText: /selected|Seleccionar categorías/i }).first().click();

    const search = form.locator("input[data-multi-select-target='searchInput']").first();
    await expect(search).toBeVisible();
    await search.fill("Automotriz");

    await expect(form.locator("label", { hasText: "Crédito Automotriz" })).toBeVisible();
    await expect(form.locator("label", { hasText: "Tarjetas de Crédito" })).toBeHidden();
  });
});
