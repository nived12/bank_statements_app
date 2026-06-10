import { expect, test } from "@playwright/test";
import {
  expectBottomNavPinnedToViewport,
  isPricingGate,
  mobileBottomNav,
  mobileFormFooter,
  mobileFormShell,
  mobileView,
} from "../helpers/mobile";

test.use({ storageState: "e2e/.auth/user.json" });

test.describe("mobile web parity (<768px)", () => {
  test("dashboard shows mobile shell and pinned bottom nav", async ({ page }) => {
    await page.goto("/dashboard");
    if (isPricingGate(page)) {
      test.skip(true, "subscription gate denied");
      return;
    }

    await expect(mobileView(page).first()).toBeVisible();
    await expectBottomNavPinnedToViewport(page);
    await expect(mobileBottomNav(page).locator('a[href="/transactions"]')).toBeVisible();
  });

  test("bottom nav navigates to transactions", async ({ page }) => {
    await page.goto("/dashboard");
    if (isPricingGate(page)) {
      test.skip(true, "subscription gate denied");
      return;
    }

    await mobileBottomNav(page).locator('a[href="/transactions"]').click();
    await page.waitForURL(/\/transactions/, { waitUntil: "domcontentloaded" });
    await expectBottomNavPinnedToViewport(page);
  });

  test("recurring new form renders mobile shell with date picker row", async ({ page }) => {
    await page.goto("/recurring/new");
    if (isPricingGate(page)) {
      test.skip(true, "subscription gate denied");
      return;
    }

    const shell = mobileFormShell(page, "recurring-series-form");
    await expect(shell.locator(".mobile-form-header-title")).toContainText(/Nuevo recurrente|New recurring/i);
    await expect(shell.locator('input[name="recurring_series[name]"]')).toBeVisible();
    await expect(shell.locator('input[name="recurring_series[expected_amount]"]')).toBeVisible();
    await expect(shell.locator(".recurring-seg-pill.active")).toHaveCount(2);

    const dateInput = shell.locator('input[name="recurring_series[next_due_date]"]');
    await expect(dateInput).toHaveClass(/mobile-form-date-overlay/);
    await dateInput.fill("2026-07-01");
    await expect(shell.locator("[data-date-display-target='text']")).toContainText(/julio|July/i);

    await expect(mobileFormFooter(page).getByRole("button", { name: /Crear|Create/i })).toBeVisible();
    await expectBottomNavPinnedToViewport(page);

    await expect(
      page.locator('div.hidden.md\\:block[data-controller*="recurring-series-form"]')
    ).toBeHidden();
  });

  test("transaction new form renders mobile shell", async ({ page }) => {
    await page.goto("/transactions/new");
    if (isPricingGate(page)) {
      test.skip(true, "subscription gate denied");
      return;
    }

    const shell = mobileFormShell(page, "transaction-form");
    await expect(shell.locator(".mobile-form-header-title")).toContainText(
      /Transacci[oó]n manual|Manual transaction/i
    );
    await expect(shell.locator('input[name="transaction[amount]"]')).toBeVisible();
    await expect(shell.locator('input[name="transaction[description]"]')).toBeVisible();
    const dateInput = shell.locator('input[name="transaction[date]"]');
    await expect(dateInput).toHaveClass(/mobile-form-date-overlay/);
    await dateInput.fill("2026-06-01");
    await expect(shell.locator("[data-date-display-target='text']")).toContainText(/junio|June/i);
    await expect(mobileFormFooter(page).getByRole("button", { name: /Guardar|Save/i })).toBeVisible();
    await expectBottomNavPinnedToViewport(page);
  });

  test("settings renders mobile sections and footer actions", async ({ page }) => {
    await page.goto("/settings");

    const shell = mobileFormShell(page, "page-transition");
    await expect(shell.getByRole("heading", { level: 2, name: /PREFERENCIAS|PREFERENCES/i })).toBeVisible();
    await expect(shell.getByRole("heading", { level: 2, name: /AYUDA Y COMENTARIOS|HELP & FEEDBACK/i })).toBeVisible();
    await expect(shell.getByRole("heading", { level: 2, name: /CUENTA|ACCOUNT/i })).toBeVisible();
    await expect(shell.getByText(/Enviar comentarios|Send feedback/i).first()).toBeVisible();
    await expectBottomNavPinnedToViewport(page);
  });

  test("profile renders mobile edit form", async ({ page }) => {
    await page.goto("/profile");

    const shell = mobileFormShell(page, "page-transition");
    await expect(shell.locator(".mobile-form-header-title")).toContainText(/Perfil|Profile/i);
    await expect(shell.locator('input[name="user[first_name]"]')).toBeVisible();
    await expect(shell.locator('input[name="user[last_name]"]')).toBeVisible();
    await expect(mobileFormFooter(page).getByRole("button", { name: /Guardar|Save/i })).toBeVisible();
    await expectBottomNavPinnedToViewport(page);
  });

  test("category new form renders mobile shell", async ({ page }) => {
    await page.goto("/categories/new");

    const shell = mobileFormShell(page, "category-form");
    await expect(shell.locator('input[name="category[name]"]')).toBeVisible();
    await expect(mobileFormFooter(page).getByRole("button", { name: /Guardar|Save/i })).toBeVisible();
    await expectBottomNavPinnedToViewport(page);
  });

  test("statement upload renders mobile shell", async ({ page }) => {
    await page.goto("/statement_files/new");

    const shell = mobileFormShell(page, "statement-upload");
    await expect(shell.locator(".mobile-form-header-title")).toContainText(
      /Subir estado de cuenta|Upload statement/i
    );
    await expect(shell.locator('select[name="statement_file[bank_account_id]"]')).toBeVisible();
    await expect(mobileFormFooter(page).getByRole("button", { name: /Subir|Upload/i })).toBeVisible();
    await expectBottomNavPinnedToViewport(page);
  });

  test("recurring index mobile header exposes new action", async ({ page }) => {
    await page.goto("/recurring");
    if (isPricingGate(page)) {
      test.skip(true, "subscription gate denied");
      return;
    }

    const mobileHeader = page.locator("header.block.md\\:hidden").locator("visible=true").first();
    await expect(mobileHeader.getByRole("heading", { level: 1 })).toContainText(/Recurrentes|Recurring/i);
    await expect(mobileHeader.locator('a[href="/recurring/new"]')).toBeVisible();
    await expectBottomNavPinnedToViewport(page);
  });
});
