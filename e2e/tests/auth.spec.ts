import { expect, test } from "@playwright/test";
import { login } from "../helpers/auth";

// Login + storageState capture lives in auth.setup.ts (setup project).
// These specs cover the user-facing logout and wrong-credentials flows.
test.describe.configure({ mode: "serial", timeout: 90_000 });

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
