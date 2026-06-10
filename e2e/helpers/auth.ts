import { expect, type Page } from "@playwright/test";

export const AUTH_FILE = "e2e/.auth/user.json";

export async function login(page: Page): Promise<void> {
  await page.goto("/session/new");
  await page.fill("#email:visible", "nivedvengilat@example.com");
  await page.fill("#password:visible", "test123");
  await page.locator("form[action='/session']").first().evaluate((form) => {
    (form as HTMLFormElement).requestSubmit();
  });
  await page.waitForURL(/\/(dashboard|legal_consent\/new)/, {
    timeout: 60_000,
    waitUntil: "domcontentloaded",
  });
  if (/\/legal_consent\/new/.test(page.url())) {
    await page.locator("input[type='checkbox']").evaluateAll((boxes: HTMLInputElement[]) =>
      boxes.forEach((b) => {
        b.checked = true;
      })
    );
    await page.locator("form[action='/legal_consent']").first().evaluate((form) => {
      (form as HTMLFormElement).requestSubmit();
    });
    await page.waitForURL(/\/dashboard/, { timeout: 60_000, waitUntil: "domcontentloaded" });
  }
  await expect(page.locator("h1").first()).toBeVisible({ timeout: 15_000 });

  if (/\/session\/new$/.test(page.url())) {
    const flashMessage = await page
      .locator(".text-red-800, .text-blue-800, [role='alert']")
      .first()
      .textContent()
      .catch(() => null);

    throw new Error(`Login did not leave /session/new. Flash: ${flashMessage || "none"}`);
  }
}
