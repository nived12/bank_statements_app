import { expect, test, type Page } from "@playwright/test";
import { readFile } from "node:fs/promises";
import { AUTH_FILE } from "../helpers/auth";
import {
  clearSearch,
  clearAllFilters,
  deleteTransactionByDescription,
  expectTransactionRow,
  fillManualTransactionForm,
  filterByBankAccount,
  filterByType,
  goToTransactionsFromSidebar,
  mxTodayIsoDate,
  openManualTransactionForm,
  saveManualTransaction,
  searchTransactions,
  sortByAmount,
  sortByDate,
  testToken
} from "../helpers/transactions";

test.describe.configure({ mode: "serial", timeout: 90_000 });
test.use({ storageState: AUTH_FILE });

async function createManualTransactionAndAssert(params: {
  page: Page;
  kind: "income" | "expense" | "transfer";
  amount: string;
  tokenPrefix: string;
  descriptionPrefix: string;
  conceptPrefix: string;
}) {
  const { page, kind, amount, tokenPrefix, descriptionPrefix, conceptPrefix } = params;
  const today = mxTodayIsoDate();
  const token = testToken(tokenPrefix);
  const description = `${descriptionPrefix} ${token}`;
  const concept = `${conceptPrefix} ${token}`;
  const reference = `REF-${token}`;

  await openManualTransactionForm(page);
  await fillManualTransactionForm(page, {
    kind,
    amount,
    description,
    date: today,
    categoryName: "Cuenta de Ahorros",
    concept,
    reference
  });
  await saveManualTransaction(page);
  await searchTransactions(page, token);
  await expectTransactionRow(page, concept, reference);
  await clearSearch(page);
}

test("manual income transaction creation works", async ({ page }) => {
  await goToTransactionsFromSidebar(page);
  await createManualTransactionAndAssert({
    page,
    kind: "income",
    amount: "123.42",
    tokenPrefix: "e2e-income",
    descriptionPrefix: "Ingreso",
    conceptPrefix: "Concepto"
  });
});

test("manual expense transaction creation works", async ({ page }) => {
  await goToTransactionsFromSidebar(page);
  await createManualTransactionAndAssert({
    page,
    kind: "expense",
    amount: "321.75",
    tokenPrefix: "e2e-expense",
    descriptionPrefix: "Gasto",
    conceptPrefix: "Concepto"
  });
});

test("manual transfer transaction creation works", async ({ page }) => {
  await goToTransactionsFromSidebar(page);
  await createManualTransactionAndAssert({
    page,
    kind: "transfer",
    amount: "222.10",
    tokenPrefix: "e2e-transfer",
    descriptionPrefix: "Transfer",
    conceptPrefix: "Concepto"
  });
});

test("transactions filters and sorting work in key journeys", async ({ page }) => {
  const today = mxTodayIsoDate();
  const filterToken = testToken("e2e-filter");
  const description = `Filtro ${filterToken}`;
  const concept = `Concepto ${filterToken}`;
  const reference = `REF-${filterToken}`;

  await goToTransactionsFromSidebar(page);
  await openManualTransactionForm(page);
  const created = await fillManualTransactionForm(page, {
    kind: "income",
    amount: "456.78",
    description,
    date: today,
    categoryName: "Cuenta de Ahorros",
    concept,
    reference
  });
  await saveManualTransaction(page);

  await searchTransactions(page, filterToken);
  await expectTransactionRow(page, concept, reference);

  await filterByBankAccount(page, created.sourceAccountId);
  await expectTransactionRow(page, concept, reference);

  await filterByType(page, "income");
  await expectTransactionRow(page, concept, reference);

  await clearAllFilters(page);
  await searchTransactions(page, filterToken);
  await expectTransactionRow(page, concept, reference);
  await clearSearch(page);

  await sortByAmount(page);
  await expect(page.locator("tbody#transactions-tbody tr[id^='transaction-']").first()).toBeVisible();
  await sortByAmount(page);
  await expect(page.locator("tbody#transactions-tbody tr[id^='transaction-']").first()).toBeVisible();

  await sortByDate(page);
  await expect(page.locator("tbody#transactions-tbody tr[id^='transaction-']").first()).toBeVisible();
});

test("transactions CSV export downloads and includes expected data", async ({ page }) => {
  const today = mxTodayIsoDate();
  const exportToken = testToken("e2e-export");
  const description = `Export ${exportToken}`;
  const concept = `Concepto ${exportToken}`;
  const reference = `REF-${exportToken}`;

  await goToTransactionsFromSidebar(page);
  await openManualTransactionForm(page);
  await fillManualTransactionForm(page, {
    kind: "income",
    amount: "789.01",
    description,
    date: today,
    categoryName: "Cuenta de Ahorros",
    concept,
    reference
  });
  await saveManualTransaction(page);

  await searchTransactions(page, exportToken);
  await expectTransactionRow(page, concept, reference);

  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("link", { name: /Exportar CSV/i }).first().click();
  const download = await downloadPromise;

  expect(download.suggestedFilename()).toMatch(/\.csv$/i);
  const csvPath = await download.path();
  expect(csvPath).not.toBeNull();

  if (!csvPath) throw new Error("CSV download path was null");

  const body = await readFile(csvPath, "utf8");
  expect(body).toMatch(/Fecha|Date/);
  expect(body).toContain(exportToken);
});

test("inline category edit routes saves to the correct row (singleton panel)", async ({ page }) => {
  const today = mxTodayIsoDate();
  const tokenA = testToken("e2e-cat-a");
  const tokenB = testToken("e2e-cat-b");

  await goToTransactionsFromSidebar(page);

  // Create two transactions so we have two distinct rows to work with
  await openManualTransactionForm(page);
  await fillManualTransactionForm(page, {
    kind: "income",
    amount: "11.11",
    description: `Cat A ${tokenA}`,
    date: today,
    categoryName: "Cuenta de Ahorros",
    concept: `Concepto ${tokenA}`,
    reference: `REF-${tokenA}`
  });
  await saveManualTransaction(page);

  await openManualTransactionForm(page);
  await fillManualTransactionForm(page, {
    kind: "income",
    amount: "22.22",
    description: `Cat B ${tokenB}`,
    date: today,
    categoryName: "Cuenta de Ahorros",
    concept: `Concepto ${tokenB}`,
    reference: `REF-${tokenB}`
  });
  await saveManualTransaction(page);

  // Filter to just these two rows
  await searchTransactions(page, "e2e-cat-");
  const tbody = page.locator("tbody#transactions-tbody");
  const rowA = tbody.locator("tr[id^='transaction-']").filter({ hasText: tokenA }).first();
  const rowB = tbody.locator("tr[id^='transaction-']").filter({ hasText: tokenB }).first();
  await expect(rowA).toBeVisible();
  await expect(rowB).toBeVisible();

  // Open the singleton dropdown on row A and pick "Educación" (a real seed category)
  await rowA.locator("[data-controller='inline-category'] button[data-action]").click();
  const panel = page.locator("[data-role='category-panel']");
  await expect(panel).toBeVisible();

  // Search to narrow the list and click the first *visible* matching item.
  // The panel hides non-matching items with inline display:none so we must
  // scope to visible nodes to avoid clicking a hidden item.
  await panel.locator("[data-role='category-search']").fill("Comida");
  await page.waitForTimeout(150);
  const categoryItemA = panel.locator("[data-role='category-item']").locator("visible=true").first();
  const categoryNameA = await categoryItemA.getAttribute("data-category-name");
  await categoryItemA.click();
  await expect(panel).toBeHidden();

  // Row A should now show the selected category; row B should be unchanged
  await expect(rowA).toContainText(categoryNameA!);
  await expect(rowB).not.toContainText(categoryNameA!);

  // Open the singleton dropdown on row B and pick a different category ("Transporte")
  await rowB.locator("[data-controller='inline-category'] button[data-action]").click();
  await expect(panel).toBeVisible();
  await panel.locator("[data-role='category-search']").fill("Transporte");
  await page.waitForTimeout(150);
  const categoryItemB = panel.locator("[data-role='category-item']").locator("visible=true").first();
  const categoryNameB = await categoryItemB.getAttribute("data-category-name");
  await categoryItemB.click();
  await expect(panel).toBeHidden();

  // Row B updated; row A's earlier selection is untouched
  await expect(rowB).toContainText(categoryNameB!);
  await expect(rowA).toContainText(categoryNameA!);
  await expect(rowA).not.toContainText(categoryNameB!);

  await clearSearch(page);
});

test("transaction can be deleted from table actions", async ({ page }) => {
  const today = mxTodayIsoDate();
  const deleteToken = testToken("e2e-delete");
  const description = `Delete ${deleteToken}`;
  const concept = `Concepto ${deleteToken}`;
  const reference = `REF-${deleteToken}`;

  await goToTransactionsFromSidebar(page);
  await openManualTransactionForm(page);
  await fillManualTransactionForm(page, {
    kind: "income",
    amount: "90.50",
    description,
    date: today,
    categoryName: "Cuenta de Ahorros",
    concept,
    reference
  });
  await saveManualTransaction(page);
  await searchTransactions(page, deleteToken);
  await expectTransactionRow(page, concept, reference);

  await deleteTransactionByDescription(page, reference);
  await expect(page.locator("body")).not.toContainText(deleteToken);
});
