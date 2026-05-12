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
