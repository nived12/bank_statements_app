import { expect, type Page } from "@playwright/test";
import { login } from "./auth";
import { desktopFormShell, desktopView } from "./desktop";

export type TransactionKind = "income" | "expense" | "transfer";

export interface ManualTransactionInput {
  kind: TransactionKind;
  amount: string;
  description: string;
  concept: string;
  reference: string;
  date: string;
  categoryName?: string;
}

export interface ManualTransactionResult {
  sourceAccountId: string;
  destinationAccountId?: string;
}

export function mxTodayIsoDate(): string {
  return new Date().toLocaleDateString("en-CA", { timeZone: "America/Mexico_City" });
}

export function testToken(prefix: string): string {
  return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 10_000)}`;
}

export async function goToTransactionsFromSidebar(page: Page): Promise<void> {
  await page.goto("/dashboard");
  if (/\/session\/new$/.test(page.url())) {
    await login(page);
  }
  const sidebarTransactionsLink = page.locator("a[href='/transactions']").first();
  if (await sidebarTransactionsLink.isVisible().catch(() => false)) {
    await sidebarTransactionsLink.click();
  }

  if (!/\/transactions/.test(page.url())) {
    await page.goto("/transactions");
  }

  await expect(page).toHaveURL(/\/transactions/);
  await expect(desktopView(page).first().locator("h1").first()).toContainText(/Transacciones/i);
}

export async function openManualTransactionForm(page: Page): Promise<void> {
  await desktopView(page).first().getByRole("link", { name: /Agregar Transacci[oó]n/i }).click();
  await expect(page).toHaveURL(/\/transactions\/new/);
  await expect(
    desktopFormShell(page, "transaction-form").getByRole("heading", { level: 1 }).first()
  ).toContainText(/Transacci[oó]n Manual/i);
}

async function chooseSourceAndDate(root: ReturnType<typeof desktopFormShell>, date: string): Promise<string> {
  const accountSelect = root.locator("#transaction_bank_account_id");
  await expect(accountSelect).toBeVisible();
  const options = await accountSelect.locator("option").all();
  const validOptions = [];

  for (const option of options) {
    const value = await option.getAttribute("value");
    if (value) validOptions.push(value);
  }

  if (validOptions.length < 1) {
    throw new Error("No valid bank account options available for source account");
  }

  const sourceAccountId = validOptions[0];
  await accountSelect.selectOption(sourceAccountId);

  await root.locator("#transaction_date").fill(date);
  await expect(root.locator("#transaction_date")).toHaveValue(date);

  return sourceAccountId;
}

async function chooseDestinationAccount(root: ReturnType<typeof desktopFormShell>, sourceAccountId: string): Promise<string> {
  const destinationSelect = root.locator("#transaction_transfer_account_id");
  await expect(destinationSelect).toBeVisible();

  const options = await destinationSelect.locator("option").all();
  const candidates: string[] = [];

  for (const option of options) {
    const value = await option.getAttribute("value");
    if (value && value !== sourceAccountId) candidates.push(value);
  }

  if (candidates.length < 1) {
    throw new Error("No valid destination account found for transfer");
  }

  await destinationSelect.selectOption(candidates[0]);
  return candidates[0];
}

async function selectCategory(root: ReturnType<typeof desktopFormShell>, categoryName: string): Promise<void> {
  await root.locator("[data-multi-select-target='button']").click();
  await root.locator("[data-multi-select-target='searchInput']").fill(categoryName);
  await root
    .locator("[data-multi-select-target='categoryLabel']")
    .filter({ hasText: new RegExp(categoryName, "i") })
    .first()
    .click();
}

export async function fillManualTransactionForm(
  page: Page,
  input: ManualTransactionInput
): Promise<ManualTransactionResult> {
  const root = desktopFormShell(page, "transaction-form");
  const categoryName = input.categoryName ?? "Cuenta de Ahorros";
  const transactionTypeInput = root.locator("input[type='hidden'][name='transaction[transaction_type]']");

  if (input.kind === "income") {
    await root.locator("[data-top-type='income']").click();
    await expect(transactionTypeInput).toHaveValue("income");
  } else if (input.kind === "expense") {
    await root.locator("[data-top-type='expense']").click();
    await root.locator("[data-sub-type='fixed_expense']").click();
    await expect(transactionTypeInput).toHaveValue("fixed_expense");
  } else {
    await root.locator("[data-top-type='transfer']").click();
    await expect(transactionTypeInput).toHaveValue("transfer_out");
  }

  await root.locator("#transaction_amount").fill(input.amount);
  await root.locator("#transaction_description").fill(input.description);

  const sourceAccountId = await chooseSourceAndDate(root, input.date);
  let destinationAccountId: string | undefined;

  await selectCategory(root, categoryName);
  await root.locator("#transaction_concept").fill(input.concept);
  await root.locator("#transaction_reference").fill(input.reference);

  if (input.kind === "transfer") {
    destinationAccountId = await chooseDestinationAccount(root, sourceAccountId);
  }

  return { sourceAccountId, destinationAccountId };
}

export async function saveManualTransaction(page: Page): Promise<void> {
  await desktopFormShell(page, "transaction-form").getByRole("button", { name: /^Guardar$/i }).click();
  await expect(page).toHaveURL(/\/transactions/);
}

export async function expectTransactionRow(
  page: Page,
  description: string,
  reference?: string
): Promise<void> {
  if (reference) {
    const rowByReference = page
      .locator("tbody#transactions-tbody tr[id^='transaction-']")
      .filter({ hasText: reference })
      .first();
    await expect(rowByReference).toBeVisible();
    return;
  }

  const row = page
    .locator("tbody#transactions-tbody tr[id^='transaction-']")
    .filter({ hasText: description })
    .first();
  await expect(row).toBeVisible();
}

export async function searchTransactions(page: Page, term: string): Promise<void> {
  await page.locator("#search").fill(term);
  await page.keyboard.press("Enter");
}

export async function clearSearch(page: Page): Promise<void> {
  await searchTransactions(page, "");
}

export async function openFilters(page: Page): Promise<void> {
  const bankAccountSelect = page.locator("#fp_bank_account_id");
  if (!(await bankAccountSelect.isVisible())) {
    await page.getByRole("button", { name: /Filtros/i }).first().click();
  }
  await expect(bankAccountSelect).toBeVisible();
}

export async function filterByBankAccount(page: Page, bankAccountId: string): Promise<void> {
  await openFilters(page);
  await page.locator("#fp_bank_account_id").selectOption(bankAccountId);
}

export async function filterByType(page: Page, type: "income" | "fixed_expense" | "variable_expense" | "transfer"): Promise<void> {
  await openFilters(page);
  await page.locator("#fp_transaction_type").selectOption(type);
}

export async function clearAllFilters(page: Page): Promise<void> {
  await openFilters(page);
  await page.getByRole("button", { name: /Limpiar todos los filtros/i }).click();
  await expect(page).toHaveURL(/\/transactions$/);
}

export async function sortByAmount(page: Page): Promise<void> {
  await page.getByRole("link", { name: /Monto/i }).first().click();
}

export async function sortByDate(page: Page): Promise<void> {
  await page.getByRole("link", { name: /Fecha/i }).first().click();
}

export async function firstRowAmount(page: Page): Promise<number> {
  const row = page.locator("tbody#transactions-tbody tr[id^='transaction-']").first();
  const amountText = await row.locator("td").nth(4).innerText();
  return parseMoneyText(amountText);
}

function parseMoneyText(text: string): number {
  const hasNegative = text.includes("-");
  const normalized = text.replace(/[^\d.,]/g, "").replace(/,/g, "");
  const amount = Number.parseFloat(normalized);
  return hasNegative ? -amount : amount;
}

export async function deleteTransactionByDescription(page: Page, rowTextMatch: string): Promise<void> {
  const row = page
    .locator("tbody#transactions-tbody tr[id^='transaction-']")
    .filter({ hasText: rowTextMatch })
    .first();
  await expect(row).toBeVisible();

  page.once("dialog", (dialog) => {
    void dialog.accept();
  });

  await row.locator(".transactions-action-delete").click();
}
