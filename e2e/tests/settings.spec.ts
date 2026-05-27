import { expect, test } from "@playwright/test";

test.use({ storageState: "e2e/.auth/user.json" });

test.describe("Settings", () => {
  test("sidebar link navigates to /settings and all three sections render", async ({ page }) => {
    await page.goto("/");
    await page.locator("a[href='/settings']").first().click();
    await page.waitForURL(/\/settings$/);

    await expect(page.getByRole("heading", { level: 1, name: /Ajustes|Settings/ })).toBeVisible();
    await expect(page.getByRole("heading", { level: 2, name: /PREFERENCIAS|PREFERENCES/ })).toBeVisible();
    await expect(page.getByRole("heading", { level: 2, name: /AYUDA Y COMENTARIOS|HELP & FEEDBACK/ })).toBeVisible();
    await expect(page.getByRole("heading", { level: 2, name: /CUENTA|ACCOUNT/ })).toBeVisible();
  });

  test("analytics opt-out toggle persists across reload", async ({ page }) => {
    await page.goto("/settings");
    const toggle = page.locator("input[type='checkbox'][name='user_setting[analytics_enabled]']");

    const initiallyChecked = await toggle.isChecked();
    // Click the visible toggle wrapper since the input is sr-only.
    await toggle.evaluate((el: HTMLInputElement) => {
      el.checked = !el.checked;
      el.form?.requestSubmit();
    });

    await page.waitForLoadState("networkidle");
    await page.reload();

    await expect(toggle).toBeChecked({ checked: !initiallyChecked });
  });

  test("feedback rows use mailto: support@vitt.io with proper subject prefixes", async ({ page }) => {
    await page.goto("/settings");

    const feedbackHref = await page.getByText(/Enviar comentarios|Send feedback/).first().locator("xpath=ancestor::a").getAttribute("href");
    expect(feedbackHref).toMatch(/^mailto:support@vitt\.io/);
    expect(feedbackHref).toContain(encodeURIComponent("[Vittio Beta]"));

    const bugHref = await page.getByText(/Reportar un problema|Report a problem/).first().locator("xpath=ancestor::a").getAttribute("href");
    expect(bugHref).toMatch(/^mailto:support@vitt\.io/);
    expect(bugHref).toContain(encodeURIComponent("[Vittio Bug]"));
  });

  test("Eliminar cuenta routes to /profile/confirm_delete", async ({ page }) => {
    await page.goto("/settings");
    await page.getByText(/Eliminar cuenta|Delete account/).first().click();
    await page.waitForURL(/\/profile\/confirm_delete$/);
  });

  test("/profile no longer shows the Danger Zone (moved to /settings)", async ({ page }) => {
    await page.goto("/profile");
    await expect(page.locator("body")).not.toContainText(/Danger zone|Zona de peligro/i);
    await expect(page.locator("a[href='/profile/confirm_delete']")).toHaveCount(0);
  });
});
