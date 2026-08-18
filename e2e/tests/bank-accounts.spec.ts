import { expect, test } from "@playwright/test";

test.use({ storageState: "e2e/.auth/user.json" });

test("bank accounts list and new form are reachable", async ({ page }) => {
  await page.goto("/bank_accounts");
  await expect(page.locator("h1").first()).toBeVisible();
  await page.locator("a[href='/bank_accounts/new']").first().click();
  await expect(page).toHaveURL(/\/bank_accounts\/new$/);
  await expect(page.locator("form[action='/bank_accounts']:visible").first()).toBeVisible();
});

// `relevant_for_balance` excludes the anchor date, because the entered figure is the
// balance at the END of that day and already contains it. That is invisible arithmetic
// unless the form says so: an account anchored the day after a -1,000 transfer read
// -552.77 against a statement closing at 447.23, purely from the ambiguity.
test("the opening balance form states which side of the day the figure means", async ({ page }) => {
  await page.goto("/bank_accounts/new");

  const form = page.locator("form[action='/bank_accounts']:visible").first();
  await expect(form).toBeVisible();

  await expect(form).toContainText(/al FINAL de la fecha|at the END of the date/i);
  await expect(form).toContainText(/POSTERIORES a esta fecha|AFTER this date/i);
});

// There are two account-creation forms, and adding the type to one of them is easy to
// mistake for finishing: /bank_accounts/new renders the shared form, while the accounts
// list carries its own mobile modal with a hand-written duplicate of the same select.
// The modal was missed when `investment` was added, so mobile web could not create one.
test("both account forms offer the investment type", async ({ page }) => {
  await page.goto("/bank_accounts/new");
  const desktopForm = page.locator("form[action='/bank_accounts']:visible").first();
  await expect(desktopForm.locator("select[name='bank_account[account_type]'] option[value='investment']"))
    .toHaveCount(1);

  await page.goto("/bank_accounts");
  // The modal is hidden until opened, so this asserts presence rather than visibility.
  await expect(
    page.locator("#mobileBankAccountForm select[name='bank_account[account_type]'] option[value='investment']")
  ).toHaveCount(1);
});

// Creation is the path most likely to break silently: `Bank#supports_account_type?` has
// no investment branch and returns false, which is correct for parser routing but would
// be fatal if anything on the write path gated on it.
test("an investment account can be created and is labelled on the list", async ({ page }) => {
  await page.goto("/bank_accounts/new");

  const form = page.locator("form[action='/bank_accounts']:visible").first();
  await expect(form).toBeVisible();

  await form.locator("select[name='bank_account[account_type]']").selectOption("investment");
  await form.locator("select[name='bank_account[bank_id]']").selectOption({ index: 1 });
  // account_number is unique per user+bank, and the suite can be re-run without re-seeding,
  // so a fixed value would fail validation on the second run. The seed prunes INV-E2E-*.
  await form.locator("input[name='bank_account[account_number]']").fill(`INV-E2E-${Date.now()}`);
  await form.locator("input[name='bank_account[custom_name]']").fill("E2E Casa de Bolsa");
  await form.locator("input[name='bank_account[opening_balance_date]']").fill("2026-01-01");
  await form.locator("input[name='bank_account[opening_balance]']").fill("25000");

  await form.locator("button[type='submit']").click();

  await expect(page).toHaveURL(/\/bank_accounts(\/\d+)?$/);
  await page.goto("/bank_accounts");

  // The list renders the same account twice — .bank-account-name for desktop and a
  // mobile row hidden at this viewport — so the desktop class is what has to be asserted.
  await expect(
    page.locator(".bank-account-name").filter({ hasText: "E2E Casa de Bolsa" }).first()
  ).toBeVisible();

  const badge = page.locator(".bank-account-badge-investment").first();
  await expect(badge).toBeVisible();
  await expect(badge).toHaveText(/Inversión|Investment/);

  // Archive it before leaving. An account left behind becomes the first entry in every
  // account dropdown, and the specs that create a transaction through the UI pick the
  // first option — so their rows land on it, dated today, and bury the seeded rows that
  // mobile-web.spec.ts looks for on page one. Three leftover accounts broke two specs.
  page.on("dialog", (dialog) => dialog.accept());

  const card = page
    .locator(".bank-account-card")
    .filter({ hasText: "E2E Casa de Bolsa" })
    .first();
  await card.locator("form[action*='/archive'] button").first().click();

  await expect(
    page.locator(".bank-account-name").filter({ hasText: "E2E Casa de Bolsa" })
  ).toHaveCount(0);
});
