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

// Both modal buttons once ignored the checkboxes entirely: discard collected *every*
// checkbox rather than the checked ones, and link rejected everything left unchecked.
// That was invisible while rows arrived pre-checked, because "all" and "selected" were
// the same set — so removing the pre-check turned both into footguns. In production a
// single click meant for one false positive discarded three real transfers worth
// $16,000, and a rejected candidate is never offered again.
//
// These assert the request payload rather than the resulting data, for two reasons: the
// ids sent *are* the bug, and stubbing the response keeps the seeded candidates intact
// so the suite stays re-runnable.
test.describe("transfer candidate selection", () => {
  test.describe.configure({ mode: "serial", timeout: 90_000 });

  async function openModalWithBothCandidates(page) {
    await page.goto("/transactions");
    await page.locator("button[data-action='transfer-candidates#reconcile']").click();

    const resultLink = page
      .locator("[data-transfer-candidates-target='resultEl'] button")
      .first();
    await expect(resultLink).toBeVisible();
    await resultLink.click();

    const modal = page.locator("[data-transfer-candidates-target='modal']");
    await expect(modal).toBeVisible();

    // Both seeded pairs must be on screen, or the test cannot tell "all" from "ticked".
    const rows = modal.locator("[data-transfer-candidates-target='tableBody'] tr");
    await expect(rows).toHaveCount(2);

    return modal;
  }

  // Captures the ids the controller submits, and answers with a stubbed success so
  // nothing is written. Returns a promise resolving to the parsed body.
  async function interceptSubmit(page) {
    let resolveBody: (value: { accepted_ids: string[]; rejected_ids: string[] }) => void;
    const body = new Promise<{ accepted_ids: string[]; rejected_ids: string[] }>((resolve) => {
      resolveBody = resolve;
    });

    await page.route("**/transactions/process_transfer_candidates", async (route) => {
      resolveBody(JSON.parse(route.request().postData() || "{}"));
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ success: true, linked_count: 0, rejected_count: 0 })
      });
    });

    return body;
  }

  test("discarding sends only the ticked row", async ({ page }) => {
    const modal = await openModalWithBothCandidates(page);
    const submitted = await interceptSubmit(page);

    const checkboxes = modal.locator("[data-transfer-candidates-target='tableBody'] input[type='checkbox']");
    const tickedId = await checkboxes.first().inputValue();
    await checkboxes.first().check();

    await page.locator("button[data-action='transfer-candidates#dismissSelected']").click();

    const body = await submitted;
    expect(body.rejected_ids).toEqual([tickedId]);
    expect(body.accepted_ids).toEqual([]);
  });

  test("linking sends only the ticked row and rejects nothing", async ({ page }) => {
    const modal = await openModalWithBothCandidates(page);
    const submitted = await interceptSubmit(page);

    const checkboxes = modal.locator("[data-transfer-candidates-target='tableBody'] input[type='checkbox']");
    const tickedId = await checkboxes.first().inputValue();
    await checkboxes.first().check();

    await page.locator("button[data-action='transfer-candidates#linkSelected']").click();

    const body = await submitted;
    expect(body.accepted_ids).toEqual([tickedId]);
    // The untouched row must survive. It used to be swept into rejected_ids, which is
    // permanent — the reconciler never re-offers a rejected candidate.
    expect(body.rejected_ids).toEqual([]);
  });

  test("neither button submits anything when no row is ticked", async ({ page }) => {
    const modal = await openModalWithBothCandidates(page);

    let submitted = false;
    await page.route("**/transactions/process_transfer_candidates", async (route) => {
      submitted = true;
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ success: true, linked_count: 0, rejected_count: 0 })
      });
    });

    await page.locator("button[data-action='transfer-candidates#dismissSelected']").click();
    await page.locator("button[data-action='transfer-candidates#linkSelected']").click();

    await expect(modal).toBeVisible();
    expect(submitted).toBe(false);
  });
});
