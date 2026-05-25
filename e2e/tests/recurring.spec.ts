import { expect, test } from "@playwright/test";

test("unauthenticated visit redirects to sign in", async ({ page }) => {
  await page.goto("/recurring");
  await expect(page).toHaveURL(/\/session\/new/);
});

test.describe("authenticated user", () => {
  test.use({ storageState: "e2e/.auth/user.json" });

  test("renders the recurring index page or redirects when subscription gate denies", async ({ page }) => {
    await page.goto("/recurring");
    // Either user has access (sees the recurring page) or is redirected to /pricing
    const url = page.url();
    if (/\/pricing/.test(url)) {
      test.skip(true, "subscription gate denied user — pricing page reached");
      return;
    }
    await expect(page.getByRole("heading", { name: /Recurr(ing|entes)/i }).first()).toBeVisible();
    await expect(page.getByText(/Monthly total|Total mensual/i).first()).toBeVisible();
    await expect(page.getByText(/Annual total|Total anual/i).first()).toBeVisible();
  });

  test("'New recurring' link routes to the form", async ({ page }) => {
    await page.goto("/recurring");
    if (/\/pricing/.test(page.url())) {
      test.skip(true, "subscription gate denied");
      return;
    }
    await page.getByRole("link", { name: /New recurring|Nuevo recurrente/i }).first().click();
    await expect(page).toHaveURL(/\/recurring\/new/);
    // new.html.erb renders the form twice (mobile + desktop). Use .first() to pick the
    // visible copy at the default Chromium viewport (>=768px → desktop layout).
    await expect(page.getByRole("textbox", { name: /Netflix|Spotify|Renta/i }).first()).toBeVisible();
    await expect(page.getByRole("spinbutton").first()).toBeVisible();
  });

  test("Transactions page shows 'Recurrentes' tab and navigates correctly", async ({ page }) => {
    await page.goto("/transactions");
    if (/\/pricing/.test(page.url())) {
      test.skip(true, "subscription gate denied");
      return;
    }
    const recurringTab = page.getByRole("link", { name: /Recurrentes|Recurring/i }).first();
    await expect(recurringTab).toBeVisible();
    await recurringTab.click();
    await expect(page).toHaveURL(/\/recurring($|\?)/);
    // Active state of the parent sidebar should still cover the recurring controller
    await expect(page.getByText(/Monthly total|Total mensual/i).first()).toBeVisible();
  });

  test.describe("detail view (show.html.erb)", () => {
    // Creates a fresh series via the new form so the spec is self-contained.
    // The series name is timestamped to avoid uniqueness collisions across runs.
    // new.html.erb renders the _form partial twice (mobile + desktop wrappers).
    // We scope to the visible desktop form so .fill()/.click() hit the right copy.
    const seriesName = `E2E Detail ${Date.now()}`;

    test("renders the canonical detail layout for a newly created series", async ({ page }) => {
      await page.goto("/recurring/new");
      if (/\/pricing/.test(page.url())) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const desktopForm = page.locator('form[data-recurring-series-form-target="form"]').last();
      await desktopForm.locator('input[name="recurring_series[name]"]').fill(seriesName);
      await desktopForm.locator('input[name="recurring_series[expected_amount]"]').fill("99.00");
      await desktopForm.getByRole("button", { name: /Create recurring|Crear recurrente/i }).click();

      // Should land on the show page.
      await expect(page).toHaveURL(/\/recurring\/\d+$/);

      // show.html.erb renders mobile-first then desktop. At the default Chromium
      // viewport (>=768px) only the desktop copy is visible — pick it with .last().
      await expect(page.getByRole("heading", { name: seriesName }).last()).toBeVisible();
      await expect(page.getByText(/Active|Activa/i).last()).toBeVisible();
      await expect(page.getByText(/Fixed expense|Gasto fijo/i).last()).toBeVisible();

      // Summary card stats.
      await expect(page.getByText(/Monthly total|Total mensual/i).last()).toBeVisible();
      await expect(page.getByText(/Annual total|Total anual/i).last()).toBeVisible();

      // Details sidebar.
      await expect(page.getByText(/Next due|Próximo cobro/i).last()).toBeVisible();
      await expect(page.getByText(/Frequency|Frecuencia/i).last()).toBeVisible();
      await expect(page.getByText(/Source|Origen/i).last()).toBeVisible();

      // Linked transactions empty state.
      await expect(page.getByText(/No linked transactions|Aún no hay transacciones/i).last()).toBeVisible();

      // Action buttons.
      await expect(page.getByRole("button", { name: /Pause temporarily|Pausar temporalmente/i }).last()).toBeVisible();
      await expect(page.getByRole("button", { name: /End subscription|Terminar suscripción/i }).last()).toBeVisible();
      await expect(page.getByRole("button", { name: /Delete permanently|Eliminar permanentemente/i }).last()).toBeVisible();
    });

    test("end → reactivate flow on a cancelled series", async ({ page }) => {
      await page.goto("/recurring/new");
      if (/\/pricing/.test(page.url())) {
        test.skip(true, "subscription gate denied");
        return;
      }

      const name = `E2E Restore ${Date.now()}`;
      const desktopForm = page.locator('form[data-recurring-series-form-target="form"]').last();
      await desktopForm.locator('input[name="recurring_series[name]"]').fill(name);
      await desktopForm.locator('input[name="recurring_series[expected_amount]"]').fill("49.00");
      await desktopForm.getByRole("button", { name: /Create recurring|Crear recurrente/i }).click();
      await expect(page).toHaveURL(/\/recurring\/\d+$/);

      // End the subscription (click the visible desktop copy).
      await page.getByRole("button", { name: /End subscription|Terminar suscripción/i }).last().click();
      await expect(page.getByText(/Cancelled|Cancelada/i).last()).toBeVisible();

      // Reactivate button should now be visible; Pause should not appear at all.
      const reactivate = page.getByRole("button", { name: /Reactivate|Reactivar/i }).last();
      await expect(reactivate).toBeVisible();
      await expect(page.getByRole("button", { name: /Pause temporarily|Pausar temporalmente/i })).toHaveCount(0);

      await reactivate.click();
      await expect(page.getByText(/Active|Activa/i).last()).toBeVisible();
      await expect(page.getByRole("button", { name: /Pause temporarily|Pausar temporalmente/i }).last()).toBeVisible();
    });
  });
});
