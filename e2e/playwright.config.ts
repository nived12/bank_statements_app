import { defineConfig, devices } from "@playwright/test";

const railsEnv =
  process.env.PLAYWRIGHT_RAILS_ENV?.trim() || (process.env.CI ? "test" : "development");

export default defineConfig({
  testDir: "./tests",
  outputDir: "test-results",
  timeout: 30_000,
  expect: {
    timeout: 10_000
  },
  fullyParallel: false,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: [
    ["list"],
    ["html", { outputFolder: "playwright-report", open: "never" }],
    ["json", { outputFile: "playwright-report/results.json" }]
  ],
  use: {
    baseURL: "http://127.0.0.1:3001",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure"
  },
  webServer: {
    command: `RAILS_ENV=${railsEnv} bin/rails server -p 3001 -P tmp/pids/server.playwright.pid`,
    cwd: "..",
    url: "http://127.0.0.1:3001",
    reuseExistingServer: !process.env.CI,
    timeout: 90_000
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] }
    }
  ]
});
