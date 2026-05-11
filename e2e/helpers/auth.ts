import { expect, type Page } from "@playwright/test";

export const AUTH_FILE = "e2e/.auth/user.json";

export async function login(page: Page): Promise<void> {
  await page.goto("/session/new");
  await page.fill("#email:visible", "nivedvengilat@example.com");
  await page.fill("#password:visible", "test123");
  await page.locator("button[type='submit']:visible").first().click();
  await page.waitForLoadState("networkidle");

  if (/\/session\/new$/.test(page.url())) {
    const flashMessage = await page
      .locator(".text-red-800, .text-blue-800, [role='alert']")
      .first()
      .textContent()
      .catch(() => null);

    throw new Error(`Login did not leave /session/new. Flash: ${flashMessage || "none"}`);
  }
}
