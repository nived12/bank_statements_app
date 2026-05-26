import { expect, test } from "@playwright/test";

// This spec creates its own fresh user via the signup form so it never
// touches the shared fixture user from auth.setup.ts. Each run also uses
// a unique email so the partial unique index on email allows re-runs.
test.describe.configure({ mode: "serial", timeout: 90_000 });

function uniqueEmail(): string {
  return `delete-test+${Date.now()}@example.com`;
}

async function signUpFreshUser(page: any, email: string, password = "password123") {
  await page.goto("/users/new");
  await page.fill("input[name='user[first_name]']", "Delete");
  await page.fill("input[name='user[last_name]']", "TestUser");
  await page.fill("input[name='user[email]']", email);
  await page.fill("input[name='user[password]']", password);
  await page.fill("input[name='user[password_confirmation]']", password);
  await page.locator("form[action='/users']").first().evaluate((form: HTMLFormElement) => {
    form.requestSubmit();
  });
  // Signup auto-logs the user in and redirects to /dashboard, which then
  // bounces to /legal_consent/new since the new user hasn't consented yet.
  // We accept either landing point — the next helper handles the consent step.
  await page.waitForURL(
    (url: URL) => /\/legal_consent\/new$|\/dashboard$/.test(url.pathname),
    { timeout: 20_000 }
  );
}

async function acceptLegalConsentIfPresent(page: any) {
  if (/\/legal_consent\/new$/.test(page.url())) {
    await page.locator("input[type='checkbox']").evaluateAll((boxes: HTMLInputElement[]) =>
      boxes.forEach((b) => { b.checked = true; })
    );
    await page.locator("form[action='/legal_consent']").first().evaluate((form: HTMLFormElement) => {
      form.requestSubmit();
    });
    await page.waitForURL((url: URL) => !url.pathname.includes("/legal_consent"), {
      timeout: 10_000
    });
  }
}

test("user archives their account from profile danger zone", async ({ page }) => {
  const email = uniqueEmail();

  await signUpFreshUser(page, email);
  await acceptLegalConsentIfPresent(page);

  // Navigate to profile → danger zone → confirm delete page
  await page.goto("/profile/confirm_delete");

  // Form is gated until the user types the exact confirmation word (ELIMINAR in es-MX).
  await page.fill("input[name='confirm']", "ELIMINAR");

  // Submit and accept the turbo_confirm dialog.
  page.once("dialog", (dialog) => dialog.accept());
  await page.locator("form[action='/profile'] [type='submit']").click();

  // After archive: session is reset, user redirected to login with success flash.
  await page.waitForURL(/\/session\/new$/, { timeout: 10_000 });
  await expect(page.locator("text=/eliminada|deleted/i").first()).toBeVisible();
});

test("archived user cannot log back in", async ({ page }) => {
  const email = uniqueEmail();
  const password = "password123";

  await signUpFreshUser(page, email, password);
  await acceptLegalConsentIfPresent(page);

  // Archive the account
  await page.goto("/profile/confirm_delete");
  await page.fill("input[name='confirm']", "ELIMINAR");
  page.once("dialog", (dialog) => dialog.accept());
  await page.locator("form[action='/profile'] [type='submit']").click();
  await page.waitForURL(/\/session\/new$/, { timeout: 10_000 });

  // Try to log back in with the same credentials → should stay on login page
  await page.fill("#email", email);
  await page.fill("#password", password);
  await page.locator("form[action='/session']").first().evaluate((form: HTMLFormElement) => {
    form.requestSubmit();
  });
  await page.waitForLoadState("networkidle");

  // Archived users get the same INVALID_CREDENTIALS response as wrong passwords —
  // we don't reveal the account exists. So we should still be on /session/new.
  expect(page.url()).toMatch(/\/session\/new$/);
});

test("same email can be reused for a fresh signup after archive", async ({ page }) => {
  const email = uniqueEmail();

  // First user signs up + archives
  await signUpFreshUser(page, email);
  await acceptLegalConsentIfPresent(page);
  await page.goto("/profile/confirm_delete");
  await page.fill("input[name='confirm']", "ELIMINAR");
  page.once("dialog", (dialog) => dialog.accept());
  await page.locator("form[action='/profile'] [type='submit']").click();
  await page.waitForURL(/\/session\/new$/, { timeout: 10_000 });

  // Brand new signup with the same email (partial unique index lets this through)
  await signUpFreshUser(page, email);
  // Should land somewhere inside the app — proving the second signup succeeded.
  expect(page.url()).not.toMatch(/\/users\/new$/);
});
