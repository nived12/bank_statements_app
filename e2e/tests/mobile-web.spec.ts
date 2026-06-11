import { expect, test } from "@playwright/test";
import {
  expectBottomNavPinnedToViewport,
  expectDesktopShellHidden,
  gotoMobile,
  mobileBottomNav,
  mobileFinancesShell,
  mobileFormFooter,
  mobileFormShell,
  mobilePageShell,
  mobileView,
} from "../helpers/mobile";

test.use({ storageState: "e2e/.auth/user.json" });

test.describe("mobile web parity (<768px)", () => {
  test.describe("navigation", () => {
    test("dashboard shows mobile shell and pinned bottom nav", async ({ page }) => {
      if (!(await gotoMobile(page, "/dashboard"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      await expect(mobileView(page).first()).toBeVisible();
      await expectBottomNavPinnedToViewport(page);
      await expect(mobileBottomNav(page).locator('a[href="/transactions"]')).toBeVisible();
    });

    test("bottom nav visits all primary tabs", async ({ page }) => {
      if (!(await gotoMobile(page, "/dashboard"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const nav = mobileBottomNav(page);
      const tabs = [
        { href: "/dashboard", url: /\/dashboard/ },
        { href: "/transactions", url: /\/transactions/ },
        { href: "/bank_accounts", url: /\/bank_accounts/ },
        { href: "/finances", url: /\/finances/ },
      ] as const;

      for (const tab of tabs) {
        await nav.locator(`a[href="${tab.href}"]`).click();
        await page.waitForURL(tab.url, { waitUntil: "domcontentloaded" });
        await expectBottomNavPinnedToViewport(page);
      }
    });

    test("mobile form back header navigates to parent", async ({ page }) => {
      await page.goto("/categories/new");

      const shell = mobileFormShell(page, "category-form");
      await shell.locator(".mobile-form-header-btn").click();
      await page.waitForURL(/\/categories$/, { waitUntil: "domcontentloaded" });
      await expectBottomNavPinnedToViewport(page);
    });
  });

  test.describe("finances", () => {
    test("segmented control switches panels", async ({ page }) => {
      if (!(await gotoMobile(page, "/finances"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const shell = mobileFinancesShell(page);
      const savingsPanel = shell.locator('[data-segmented-control-target="panel"][data-tab="savings"]');
      const debtsPanel = shell.locator('[data-segmented-control-target="panel"][data-tab="debts"]');
      const goalsPanel = shell.locator('[data-segmented-control-target="panel"][data-tab="goals"]');

      await expect(savingsPanel).toBeVisible();
      await expect(debtsPanel).toBeHidden();
      await expect(goalsPanel).toBeHidden();

      await shell.locator('[data-segmented-control-target="tab"][data-tab="debts"]').click();
      await expect(debtsPanel).toBeVisible();
      await expect(savingsPanel).toBeHidden();

      await shell.locator('[data-segmented-control-target="tab"][data-tab="goals"]').click();
      await expect(goalsPanel).toBeVisible();
      await expect(debtsPanel).toBeHidden();

      await expectBottomNavPinnedToViewport(page);
    });

    test("FAB href tracks active tab", async ({ page }) => {
      if (!(await gotoMobile(page, "/finances"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const shell = mobileFinancesShell(page);
      const addButton = shell.locator('[data-segmented-control-target="addButton"]');

      await expect(addButton).toHaveAttribute("href", /\/savings\/new$/);
      await shell.locator('[data-segmented-control-target="tab"][data-tab="debts"]').click();
      await expect(addButton).toHaveAttribute("href", /\/debts\/new$/);
      await shell.locator('[data-segmented-control-target="tab"][data-tab="goals"]').click();
      await expect(addButton).toHaveAttribute("href", /\/goals\/new$/);
    });
  });

  test.describe("bank accounts", () => {
    test("mobile accounts list shows seeded accounts", async ({ page }) => {
      if (!(await gotoMobile(page, "/bank_accounts"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const shell = mobilePageShell(page);
      await expect(shell.locator(".mobile-account-row-name", { hasText: "BBVA TDC" })).toBeVisible();
      await expectBottomNavPinnedToViewport(page);
    });

    test("bank account new renders mobile shell", async ({ page }) => {
      if (!(await gotoMobile(page, "/bank_accounts/new"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const shell = mobileFormShell(page, "bank-account-form");
      await expect(shell.locator('input[name="bank_account[custom_name]"]')).toBeVisible();
      await expect(mobileFormFooter(page).getByRole("button", { name: /Guardar|Save/i })).toBeVisible();
      await expectBottomNavPinnedToViewport(page);
      await expectDesktopShellHidden(page, "bank-account-form");
    });
  });

  test.describe("dashboard", () => {
    test("month picker navigates to selected month", async ({ page }) => {
      if (!(await gotoMobile(page, "/dashboard"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const monthPicker = page.locator('[data-controller*="month-picker"]');
      await monthPicker.locator(".mobile-month-picker-btn").click();
      await expect(monthPicker.locator("[data-month-picker-target='panel'].open")).toBeVisible();

      const monthButton = monthPicker.locator("[data-month-picker-target='panel'] button[data-month]").last();
      const monthValue = await monthButton.getAttribute("data-month");
      expect(monthValue).toBeTruthy();

      await monthButton.click();
      await page.waitForURL(new RegExp(`month=${monthValue?.replace(/-/g, "\\-")}`), {
        waitUntil: "domcontentloaded",
      });
    });
  });

  test.describe("transaction form pickers", () => {
    test("account picker sheet selects an account", async ({ page }) => {
      if (!(await gotoMobile(page, "/transactions/new"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const shell = mobileFormShell(page, "transaction-form");
      const accountBlock = shell.locator('[data-controller="form-picker"]').first();
      await accountBlock.locator('button[data-action*="form-picker#open"]').click();
      await expect(accountBlock.locator(".mobile-picker-sheet.open")).toBeVisible();

      const firstOption = accountBlock.locator('[data-form-picker-target="option"]').first();
      const label = await firstOption.getAttribute("data-label");
      await firstOption.click();

      await expect(accountBlock.locator('[data-form-picker-target="label"]')).toContainText(label ?? "");
      await expectDesktopShellHidden(page, "transaction-form");
    });

    test("category picker sheet opens with search", async ({ page }) => {
      if (!(await gotoMobile(page, "/transactions/new"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const shell = mobileFormShell(page, "transaction-form");
      const categoryBlock = shell.locator(".tx-cat-sheet").locator("..");
      await categoryBlock.locator('button[data-action*="form-picker#open"]').click();
      await expect(categoryBlock.locator(".mobile-picker-sheet.open")).toBeVisible();
      await expect(categoryBlock.locator('[data-form-picker-target="search"]')).toBeVisible();
    });
  });

  test.describe("profile sheet", () => {
    test("opens from header avatar and closes on backdrop", async ({ page }) => {
      if (!(await gotoMobile(page, "/dashboard"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      await page.locator('button[data-action*="profile-sheet#open"]').click();
      const panel = page.locator("[data-profile-sheet-target='panel']");
      await expect(panel).toHaveClass(/open/);
      await expect(panel.getByRole("link", { name: /Editar perfil|Edit profile/i })).toBeVisible();
      await expect(panel.getByRole("link", { name: /Ajustes|Settings/i })).toBeVisible();

      await page.keyboard.press("Escape");
      await expect(panel).not.toHaveClass(/open/);
    });
  });

  test.describe("list screens", () => {
    test("transactions list renders mobile shell", async ({ page }) => {
      if (!(await gotoMobile(page, "/transactions"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      await expect(page.getByRole("link", { name: /Netflix Subscription|Supermercado Walmart/i }).first()).toBeVisible();
      await expect(page.locator("header.hidden.md\\:block").first()).toBeHidden();
      await expectBottomNavPinnedToViewport(page);
    });

    test("categories index renders mobile header", async ({ page }) => {
      await page.goto("/categories");

      const mobileHeader = page.locator("header.block.md\\:hidden").locator("visible=true").first();
      await expect(mobileHeader.getByRole("heading", { level: 1 })).toContainText(
        /Categor[ií]as|Categories/i
      );
      await expectBottomNavPinnedToViewport(page);
    });

    test("statement files index renders mobile header", async ({ page }) => {
      if (!(await gotoMobile(page, "/statement_files"))) {
        test.skip(true, "subscription gate denied — statement files require premium/trial");
        return;
      }

      const mobileHeader = page.locator("header.block.md\\:hidden").locator("visible=true").first();
      await expect(mobileHeader.getByRole("heading", { level: 1 })).toBeVisible();
      await expect(page.locator(".mobile-statement-files-stats")).toBeVisible();
      await expectBottomNavPinnedToViewport(page);
    });
  });

  test.describe("form smokes", () => {
    test("recurring new form renders mobile shell with date picker row", async ({ page }) => {
      if (!(await gotoMobile(page, "/recurring/new"))) {
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
      await expectDesktopShellHidden(page, "recurring-series-form");
    });

    test("transaction new form renders mobile shell", async ({ page }) => {
      if (!(await gotoMobile(page, "/transactions/new"))) {
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

      const shell = mobileFormShell(page);
      await expect(shell.getByRole("heading", { level: 2, name: /PREFERENCIAS|PREFERENCES/i })).toBeVisible();
      await expect(shell.getByRole("heading", { level: 2, name: /AYUDA Y COMENTARIOS|HELP & FEEDBACK/i })).toBeVisible();
      await expect(shell.getByRole("heading", { level: 2, name: /CUENTA|ACCOUNT/i })).toBeVisible();
      await expect(shell.getByText(/Enviar comentarios|Send feedback/i).first()).toBeVisible();
      await expectBottomNavPinnedToViewport(page);
    });

    test("profile renders mobile edit form", async ({ page }) => {
      await page.goto("/profile");

      const shell = mobileFormShell(page);
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
      if (!(await gotoMobile(page, "/statement_files/new"))) {
        test.skip(true, "subscription gate denied — statement upload requires premium/trial");
        return;
      }

      const shell = mobileFormShell(page, "statement-upload");
      await expect(shell.locator(".mobile-form-header-title")).toContainText(
        /Subir estado de cuenta|Upload statement/i
      );
      await expect(shell.getByLabel(/Bank Account|Cuenta [Bb]ancaria/i)).toBeVisible();
      await expect(mobileFormFooter(page).getByRole("button", { name: /Subir|Upload/i })).toBeVisible();
      await expectBottomNavPinnedToViewport(page);
    });

    test("goals new form renders mobile shell", async ({ page }) => {
      if (!(await gotoMobile(page, "/goals/new"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const shell = mobileFormShell(page, "goal-form");
      await expect(shell.locator('input[name="goal[name]"]')).toBeVisible();
      await expect(mobileFormFooter(page).getByRole("button", { name: /Guardar|Save/i })).toBeVisible();
      await expectBottomNavPinnedToViewport(page);
    });

    test("debts new form renders mobile shell", async ({ page }) => {
      if (!(await gotoMobile(page, "/debts/new"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const shell = mobileFormShell(page, "debt-form");
      await expect(shell.locator('input[name="debt[name]"]')).toBeVisible();
      await expect(mobileFormFooter(page).getByRole("button", { name: /Guardar|Save/i })).toBeVisible();
      await expectBottomNavPinnedToViewport(page);
    });

    test("savings new form renders mobile shell", async ({ page }) => {
      if (!(await gotoMobile(page, "/savings/new"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const shell = mobileFormShell(page, "saving-form");
      await expect(shell.locator('input[name="saving[name]"]')).toBeVisible();
      await expect(mobileFormFooter(page).getByRole("button", { name: /Guardar|Save/i })).toBeVisible();
      await expectBottomNavPinnedToViewport(page);
    });
  });

  test.describe("edit screens", () => {
    test("recurring edit renders mobile shell", async ({ page }) => {
      if (!(await gotoMobile(page, "/recurring"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const seriesHref = await page.getByRole("link", { name: /E2E Netflix/i }).getAttribute("href");
      expect(seriesHref).toMatch(/\/recurring\/\d+/);
      await page.goto(`${seriesHref}/edit`);

      const shell = mobileFormShell(page, "recurring-series-form");
      await expect(shell.locator(".mobile-form-header-title")).toContainText(/Editar recurrente|Edit recurring/i);
      await expect(shell.locator('input[name="recurring_series[name]"]')).toHaveValue(/E2E Netflix/);
      await expect(mobileFormFooter(page).getByRole("button", { name: /Guardar|Save/i })).toBeVisible();
    });

    test("transaction edit renders mobile shell", async ({ page }) => {
      if (!(await gotoMobile(page, "/transactions"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const editHref = await page.getByRole("link", { name: /Netflix Subscription/i }).getAttribute("href");
      expect(editHref).toMatch(/\/transactions\/\d+\/edit/);
      await page.goto(editHref!);

      const shell = mobileFormShell(page, "transaction-form");
      await expect(shell.locator(".mobile-form-header-title")).toContainText(
        /Editar transacci[oó]n|Edit transaction/i
      );
      await expect(mobileFormFooter(page).getByRole("button", { name: /Guardar|Save/i })).toBeVisible();
    });
  });

  test.describe("recurring index", () => {
    test("mobile header exposes new action", async ({ page }) => {
      if (!(await gotoMobile(page, "/recurring"))) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const mobileHeader = page.locator("header.block.md\\:hidden").locator("visible=true").first();
      await expect(mobileHeader.getByRole("heading", { level: 1 })).toContainText(/Recurrentes|Recurring/i);
      await expect(mobileHeader.locator('a[href="/recurring/new"]')).toBeVisible();
      await expectBottomNavPinnedToViewport(page);
    });
  });
});
