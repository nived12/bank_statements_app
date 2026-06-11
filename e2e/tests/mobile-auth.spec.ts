import { expect, test } from "@playwright/test";

test.describe("mobile auth pages (<768px)", () => {
  test("login page renders with light logo", async ({ page }) => {
    await page.goto("/session/new");

    await expect(page.locator(".auth-page")).toBeVisible();
    await expect(page.locator("#email")).toBeVisible();
    await expect(page.locator("#password")).toBeVisible();
    await expect(page.locator(".auth-page .md\\:hidden img[alt='Vittio']")).toBeVisible();
    await expect(page.locator('.auth-page img[src*="dark_bg"]')).toHaveCount(0);
  });

  test("signup page renders registration form", async ({ page }) => {
    await page.goto("/users/new");

    await expect(page.locator(".auth-page")).toBeVisible();
    await expect(page.locator('input[name="user[email]"]')).toBeVisible();
    await expect(page.locator('input[name="user[first_name]"]')).toBeVisible();
    await expect(page.locator('input[name="user[last_name]"]')).toBeVisible();
    await expect(page.locator(".auth-page .md\\:hidden img[alt='Vittio']")).toBeVisible();
  });
});
