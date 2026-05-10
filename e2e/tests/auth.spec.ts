import { expect, test } from "@playwright/test";
import { AUTH_FILE, login } from "../helpers/auth";

test.describe.configure({ mode: "serial" });

test("login succeeds and saves auth state", async ({ page }) => {
  await login(page);
  await page.context().storageState({ path: AUTH_FILE });
  await expect(page.locator("h1").first()).toBeVisible();
});

test("logout redirects back to sign in", async ({ page }) => {
  await login(page);
  await page.getByTitle(/sign out|cerrar sesi[oó]n/i).first().click();
  await expect(page).toHaveURL(/\/session\/new$/);
  await expect(page.locator("#email")).toBeVisible();
});

test("wrong credentials stay on login page", async ({ page }) => {
  await page.goto("/session/new");
  await page.fill("#email", "nivedvengilat@example.com");
  await page.fill("#password", "wrong-password");
  await page.click("button[type='submit']");
  await expect(page).toHaveURL(/\/session\/new$/);
  await expect(page.locator("#email")).toBeVisible();
});
