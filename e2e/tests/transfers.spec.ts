import { expect, test } from "@playwright/test";
import { AUTH_FILE } from "../helpers/auth";

test.use({ storageState: AUTH_FILE });

// The bug this covers: reconciliation reported "N candidatos para revisar" and clicking
// the link did nothing at all — no modal, no error, nothing in the console. The reported
// count came from candidate rows created, while the modal reads TransferCandidate.linkable,
// and open() swallowed the mismatch in a bare catch.
//
// The pair is seeded (db/seeds/playwright.rb) because TransferReconciler only considers
// source: :statement_file rows, which the UI cannot create. It is dated two days apart so
// it lands on the candidate path rather than being auto-linked.
test.describe("transfer candidate review", () => {
  test.describe.configure({ mode: "serial", timeout: 90_000 });

  test("reconciling surfaces a candidate link that opens a populated modal", async ({ page }) => {
    await page.goto("/transactions");
    await expect(page.locator("h1").first()).toBeVisible();

    const reconcileButton = page.locator("button[data-action='transfer-candidates#reconcile']");
    await expect(reconcileButton).toBeVisible();
    await reconcileButton.click();

    // The result element becomes a clickable button only when candidates exist.
    const resultLink = page
      .locator("[data-transfer-candidates-target='resultEl'] button")
      .first();
    await expect(resultLink).toBeVisible();

    await resultLink.click();

    const modal = page.locator("[data-transfer-candidates-target='modal']");
    await expect(modal).toBeVisible();

    // Populated, not the empty-state row — the regression was an empty or absent modal.
    const rows = modal.locator("[data-transfer-candidates-target='tableBody'] tr");
    await expect(rows.first()).toBeVisible();
    await expect(modal).toContainText("7,777.00");

    // The window widened from ±1 to ±3 days, so the label is now pluralised. A seeded
    // pair two days apart would have read "1 day apart" under the old hardcoded copy.
    await expect(modal).toContainText(/2 d[ií]as de diferencia|2 days apart/);
  });

  test("the modal closes without linking anything", async ({ page }) => {
    await page.goto("/transactions");

    const reconcileButton = page.locator("button[data-action='transfer-candidates#reconcile']");
    await reconcileButton.click();

    const resultLink = page
      .locator("[data-transfer-candidates-target='resultEl'] button")
      .first();
    await expect(resultLink).toBeVisible();
    await resultLink.click();

    const modal = page.locator("[data-transfer-candidates-target='modal']");
    await expect(modal).toBeVisible();

    await page.locator("button[data-action='transfer-candidates#close']").first().click();
    await expect(modal).toBeHidden();

    // Still a candidate, still untouched: reviewing is opt-in, and re-running the spec
    // must not consume the seeded pair.
    await expect(
      page.locator("[data-transfer-candidates-target='resultEl']")
    ).toBeVisible();
  });
});
