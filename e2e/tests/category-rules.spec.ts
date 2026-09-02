import { expect, test } from "@playwright/test";
import { AUTH_FILE } from "../helpers/auth";
import { clearSearch, searchTransactions } from "../helpers/transactions";

test.describe.configure({ mode: "serial" });
test.use({ storageState: AUTH_FILE });

// Seeded in db/seeds/playwright.rb: the pattern omits the account number that the
// statement row carries in the middle of its description.
const RULE_PATTERN = "pago de prestamo total de recibo";
const ROW_DESCRIPTION = "PAGO DE PRESTAMO 9837815631 TOTAL DE RECIBO";

function ruleRow(page: import("@playwright/test").Page) {
  return page.locator("#category-rules-list tr").filter({ hasText: RULE_PATTERN }).first();
}

// A rule is learned from one wording of a description, but the next statement phrases the
// same transaction differently — usually by keeping or dropping an embedded account number.
// A rule that only matched the exact substring silently stopped working at that point.
test("a contains rule reaches a description that interrupts its pattern", async ({ page }) => {
  await page.goto("/category_rules");

  const row = ruleRow(page);
  await expect(row).toBeVisible();
  await expect(row).toContainText("Crédito Automotriz");

  // The hit count is the part that proves the rule fired rather than merely existing.
  const hits = Number(await row.locator("td").nth(3).innerText());
  expect(hits).toBeGreaterThan(0);
});

test("the categorized transaction shows the rule's category, not the AI's", async ({ page }) => {
  await page.goto("/transactions");
  await searchTransactions(page, ROW_DESCRIPTION);

  const row = page.locator("tbody tr").filter({ hasText: ROW_DESCRIPTION }).first();
  await expect(row).toBeVisible();
  await expect(row).toContainText("Crédito Automotriz");
  await expect(row).not.toContainText("Préstamos Personales");

  await clearSearch(page);
});

test("a rule can be created, deactivated and deleted from the rules page", async ({ page }) => {
  const pattern = `e2e regla ${Date.now()}`;

  await page.goto("/category_rules");
  // The toolbar toggle and the form's submit share the same label, so scope to the toggle.
  await page.locator("button[data-toggle-panel-target-value='new-rule-form']").first().click();

  const form = page.locator("#new-rule-form");
  await expect(form).toBeVisible();
  await form.locator("#category_rule_pattern").fill(pattern);
  await form.locator("#category_rule_match_type").selectOption("contains");

  // The picker is a Stimulus multi-select: open it, then click the label whose radio
  // carries the category id — the radio itself is visually hidden.
  await form.getByRole("button", { name: /Seleccionar Categor[ií]a/i }).click();
  await form.locator("label[data-multi-select-target='categoryLabel']")
    .filter({ hasText: "Crédito Automotriz" })
    .first()
    .click();
  await form.locator("input[type='submit']").click();

  const created = page.locator("#category-rules-list tr").filter({ hasText: pattern }).first();
  await expect(created).toBeVisible();

  // The checkbox is sr-only behind a styled track, so the label is the clickable target.
  // The toggle PATCHes in the background — reloading before it lands reads the old row.
  const persisted = page.waitForResponse(
    (response) =>
      /\/category_rules\/\d+$/.test(new URL(response.url()).pathname) &&
      response.request().method() === "PATCH"
  );
  await created.locator("div[data-controller='toggle-active'] label").first().click();
  await persisted;
  await page.reload();
  await expect(
    page.locator("#category-rules-list tr").filter({ hasText: pattern }).first()
      .locator("input[type='checkbox']").first()
  ).not.toBeChecked();

  page.on("dialog", (dialog) => dialog.accept());
  await page.locator("#category-rules-list tr").filter({ hasText: pattern }).first()
    .locator("button[type='submit']").first().click();

  await expect(page.locator("#category-rules-list tr").filter({ hasText: pattern })).toHaveCount(0);
});
