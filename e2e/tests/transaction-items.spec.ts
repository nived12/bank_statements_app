import { expect, test, type Page } from "@playwright/test";
import { AUTH_FILE } from "../helpers/auth";
import {
  deleteTransactionByDescription,
  fillManualTransactionForm,
  goToTransactionsFromSidebar,
  mxTodayIsoDate,
  openManualTransactionForm,
  saveManualTransaction,
  searchTransactions,
  clearSearch,
  testToken,
} from "../helpers/transactions";

test.describe.configure({ mode: "serial", timeout: 90_000 });
test.use({ storageState: AUTH_FILE });

const TOKEN = testToken("items-e2e");
const DESCRIPTION = `Despensa e2e ${TOKEN}`;

function itemsDisclosure(page: Page) {
  // Both new.html.erb and edit.html.erb render two form copies (mobile + desktop).
  // Desktop Chrome viewport shows the "hidden md:block" section — scope to it.
  return page
    .locator(".md\\:block")
    .locator("[data-controller='transaction-items']")
    .first();
}

async function expandItemsDisclosure(page: Page): Promise<void> {
  const details = itemsDisclosure(page);
  const isOpen = await details.evaluate((el) => (el as HTMLDetailsElement).open);
  if (!isOpen) {
    await details.locator("summary").click();
    await expect(details).toHaveAttribute("open");
  }
}

function visibleItemRows(page: Page) {
  return itemsDisclosure(page)
    .locator("[data-transaction-items-row]")
    .filter({ hasNot: page.locator("[style*='display: none']") });
}

async function addItemRow(page: Page, name: string, amount: string): Promise<void> {
  await page.getByRole("button", { name: /Agregar artículo/i }).click();
  const lastRow = visibleItemRows(page).last();
  await lastRow.locator("input[type='text']").fill(name);
  await lastRow.locator("[data-item-amount]").fill(amount);
  await lastRow.locator("[data-item-amount]").blur();
}

async function openEditForm(page: Page, rowTextMatch: string): Promise<void> {
  const row = page
    .locator("tbody#transactions-tbody tr[id^='transaction-']")
    .filter({ hasText: rowTextMatch })
    .first();
  await expect(row).toBeVisible();
  const rowId = await row.getAttribute("id"); // "transaction-123"
  const id = rowId?.replace("transaction-", "");
  if (!id) throw new Error(`Could not extract transaction ID from row: ${rowId}`);
  await page.goto(`/transactions/${id}/edit`);
  await expect(page).toHaveURL(/\/transactions\/\d+\/edit/);
}

// --- Tests ---

test("disclosure is collapsed by default on a plain new transaction", async ({ page }) => {
  await goToTransactionsFromSidebar(page);
  await openManualTransactionForm(page);

  const details = itemsDisclosure(page);
  await expect(details).toBeVisible();
  await expect(details).not.toHaveAttribute("open");
});

test("create transaction with items and tax saves and shows badge on list", async ({ page }) => {
  await goToTransactionsFromSidebar(page);
  await openManualTransactionForm(page);

  await fillManualTransactionForm(page, {
    kind: "expense",
    amount: "150",
    description: DESCRIPTION,
    concept: `Tacos ${TOKEN}`,
    reference: `REF-${TOKEN}`,
    date: mxTodayIsoDate(),
  });

  await expandItemsDisclosure(page);
  await addItemRow(page, "Taco Lengua", "45.50");
  await addItemRow(page, "Refresco", "25.00");

  await itemsDisclosure(page).locator("[data-tax-input]").fill("11.92");
  await itemsDisclosure(page).locator("[data-tax-input]").blur();

  await saveManualTransaction(page);

  await searchTransactions(page, TOKEN);
  const row = page
    .locator("tbody#transactions-tbody tr[id^='transaction-']")
    .filter({ hasText: TOKEN })
    .first();
  await expect(row).toBeVisible();
  await expect(row.locator("span").filter({ hasText: /artículo/i })).toBeVisible();
  await clearSearch(page);
});

test("edit: disclosure auto-opens and items are pre-populated", { timeout: 120_000 }, async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto(`/transactions?search=${encodeURIComponent(TOKEN)}`);
  await expect(page).toHaveURL(/\/transactions/);
  await openEditForm(page, TOKEN);

  await expect(itemsDisclosure(page)).toHaveAttribute("open");
  await expect(visibleItemRows(page)).toHaveCount(2);
  await expect(visibleItemRows(page).first().locator("input[type='text']")).toHaveValue("Taco Lengua");
  await expect(visibleItemRows(page).nth(1).locator("input[type='text']")).toHaveValue("Refresco");
  await expect(itemsDisclosure(page).locator("[data-tax-input]")).toHaveValue("11.92");
});

test("add and remove items round-trip correctly", { timeout: 120_000 }, async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto(`/transactions?search=${encodeURIComponent(TOKEN)}`);
  await expect(page).toHaveURL(/\/transactions/);
  await openEditForm(page, TOKEN);

  await addItemRow(page, "Agua", "10.00");
  await expect(visibleItemRows(page)).toHaveCount(3);

  // remove Refresco — filter by input attribute (hasText won't match input values)
  const refrescoRow = visibleItemRows(page)
    .filter({ has: page.locator("input[type='text'][value='Refresco']") })
    .first();
  await refrescoRow.getByRole("button").click({ force: true });

  await saveManualTransaction(page);

  await page.goto(`/transactions?search=${encodeURIComponent(TOKEN)}`);
  await openEditForm(page, TOKEN);

  await expect(itemsDisclosure(page)).toHaveAttribute("open");
  await expect(visibleItemRows(page)).toHaveCount(2);
  await expect(visibleItemRows(page).first().locator("input[type='text']")).toHaveValue("Taco Lengua");
  await expect(visibleItemRows(page).nth(1).locator("input[type='text']")).toHaveValue("Agua");
});

test("plain transaction without items keeps disclosure collapsed on edit", async ({ page }) => {
  await goToTransactionsFromSidebar(page);

  // Find the first row that does NOT have an items badge (plain transaction)
  const plainRow = page
    .locator("tbody#transactions-tbody tr[id^='transaction-']")
    .filter({ hasNot: page.locator("span").filter({ hasText: /artículo/i }) })
    .first();
  await expect(plainRow).toBeVisible();
  const href = await plainRow.locator("a[href*='/edit']").getAttribute("href");
  if (!href) test.skip(true, "No editable transaction found");

  await page.goto(href!);
  await expect(page).toHaveURL(/\/transactions\/\d+\/edit/);

  const details = itemsDisclosure(page);
  await expect(details).toBeVisible();
  await expect(details).not.toHaveAttribute("open");
});

test("cleanup: delete the e2e items transaction", async ({ page }) => {
  await goToTransactionsFromSidebar(page);
  await searchTransactions(page, TOKEN);
  await deleteTransactionByDescription(page, TOKEN);
  await clearSearch(page);
});
