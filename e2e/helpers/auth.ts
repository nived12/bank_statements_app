import { expect, type Page } from "@playwright/test";

export const AUTH_FILE = "e2e/.auth/user.json";

export async function login(page: Page): Promise<void> {
  await page.goto("/session/new");
  await page.fill("#email", "nivedvengilat@example.com");
  await page.fill("#password", "test123");
  await page.click("button[type='submit']");
  await expect(page).toHaveURL(/\/(dashboard)?$/);
  await expect(page.locator("h1").first()).toBeVisible();
}
