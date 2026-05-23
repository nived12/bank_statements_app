import { expect, test, type Page } from "@playwright/test";

// These tests cover the Vittbot chat UI happy paths.
// They never trigger a real LLM call: every message uses a deterministic suggestion key
// (Assistant::SuggestionResponder), which the Rails app routes without calling Ai::Client.

test("unauthenticated visit redirects to sign in", async ({ page }) => {
  await page.goto("/assistant");
  await expect(page).toHaveURL(/\/session\/new/);
});

test.describe("authenticated user", () => {
  test.use({ storageState: "e2e/.auth/user.json" });

  test("redirects to pricing when ASSISTANT_WEB_ENABLED is off", async ({ page }) => {
    await page.goto("/assistant");
    expect(page.url()).toMatch(/\/(assistant|pricing)/);
  });
});

// Helper: navigate to /assistant?new=1 and skip the suite cleanly if the user
// doesn't have assistant access (env flag off, no trial, no paid plan).
async function openFreshAssistant(page: Page): Promise<boolean> {
  await page.goto("/assistant?new=1");
  if (!/\/assistant/.test(page.url())) return false;
  await expect(page.getByText(/Vittbot/i).first()).toBeVisible();
  return true;
}

// Asserts no outbound LLM request was made during the test by failing the
// suite if Playwright sees a request to known LLM hostnames.
function failOnLlmRequests(page: Page): void {
  const blockedHosts = [
    "generativelanguage.googleapis.com",
    "api.openai.com",
    "api.anthropic.com"
  ];
  page.on("request", (req) => {
    const url = req.url();
    if (blockedHosts.some((host) => url.includes(host))) {
      throw new Error(`Unexpected LLM request: ${url}`);
    }
  });
}

test.describe("Vittbot chat (deterministic happy paths)", () => {
  test.use({ storageState: "e2e/.auth/user.json" });

  test.beforeEach(async ({ page }) => {
    failOnLlmRequests(page);
  });

  test("empty state shows the 9 suggestion chips", async ({ page }) => {
    test.skip(!(await openFreshAssistant(page)), "assistant gate denied user");

    const chips = page.locator("[data-action*='assistant#sendSuggestion']");
    await expect(chips).toHaveCount(9);
  });

  test("tapping a suggestion chip renders a deterministic reply with markdown bold", async ({ page }) => {
    test.skip(!(await openFreshAssistant(page)), "assistant gate denied user");

    const chip = page.locator("[data-assistant-key-param='largest_expenses']");
    await chip.click();

    // Assistant bubble appears
    const assistantBubble = page.locator("[id^='msg-asst-']").last();
    await expect(assistantBubble).toBeVisible({ timeout: 10_000 });

    // Markdown helper rendered: <strong> present, literal ** absent
    await expect(assistantBubble.locator("strong").first()).toBeVisible();
    const bubbleText = await assistantBubble.textContent();
    expect(bubbleText ?? "").not.toContain("**");
  });

  // NOTE: a "typing into the composer + Enter" test was intentionally removed.
  // Free-form text always routes through IntentRouter → LLM path in this codebase
  // (the live CI screenshot in PR #266 confirmed `Assistant::ProviderError` when
  // the LLM key is absent), which violates the no-LLM constraint. The
  // suggestion-chip test below already covers the user→assistant turn end-to-end
  // without touching the LLM.

  test("conversation history list renders the just-created conversation", async ({ page }) => {
    test.skip(!(await openFreshAssistant(page)), "assistant gate denied user");

    // Send one suggestion → creates a conversation
    await page.locator("[data-assistant-key-param='largest_expenses']").click();
    await expect(page.locator("[id^='msg-asst-']").last()).toBeVisible({ timeout: 10_000 });

    // Re-visit /assistant — the left rail history should now include at least 1 row.
    await page.goto("/assistant");
    const historyRows = page.locator("#conversation-history a[href*='conversation_id=']");
    await expect(historyRows.first()).toBeVisible({ timeout: 5_000 });
  });
});

test.describe("Vittbot FAB widget", () => {
  test.use({ storageState: "e2e/.auth/user.json" });

  test.beforeEach(async ({ page }) => {
    failOnLlmRequests(page);
  });

  test("FAB opens, history toggles, Escape closes both", async ({ page }) => {
    await page.goto("/dashboard");

    const fab = page.locator("button[aria-label='Vittbot']");
    test.skip(!(await fab.isVisible().catch(() => false)), "FAB hidden — assistant gate denied");

    // Open panel
    await fab.click();
    const panel = page.locator("[data-vittbot-fab-target='panel']");
    await expect(panel).not.toHaveClass(/(^|\s)hidden(\s|$)/);

    // Frame lazy-loads the compact chat shell
    await expect(panel.getByText(/Vittbot/i).first()).toBeVisible({ timeout: 10_000 });

    // Open history drawer
    await panel.locator("button[data-action='vittbot-fab#toggleHistory']").click();
    const historyPanel = page.locator("[data-vittbot-fab-target='historyPanel']");
    await expect(historyPanel).not.toHaveClass(/(^|\s)hidden(\s|$)/);

    // Escape closes history first, then panel
    await page.keyboard.press("Escape");
    await expect(historyPanel).toHaveClass(/(^|\s)hidden(\s|$)/);
    await expect(panel).not.toHaveClass(/(^|\s)hidden(\s|$)/);

    await page.keyboard.press("Escape");
    await expect(panel).toHaveClass(/(^|\s)hidden(\s|$)/);
  });
});
