import { defineConfig, devices } from "@playwright/test";

const railsEnv =
  process.env.PLAYWRIGHT_RAILS_ENV?.trim() || (process.env.CI ? "test" : "development");

export default defineConfig({
  testDir: "./tests",
  outputDir: "test-results",
  timeout: 60_000,
  expect: {
    timeout: 15_000
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
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure"
  },
  webServer: {
    command: `PLAYWRIGHT_E2E=1 RAILS_ENV=${railsEnv} bin/rails server -p 3001 -P tmp/pids/server.playwright.pid`,
    cwd: "..",
    url: "http://127.0.0.1:3001",
    reuseExistingServer: !(process.env.CI || process.env.PLAYWRIGHT_E2E === "1"),
    timeout: 90_000
  },
  projects: [
    {
      name: "setup",
      testMatch: /.*\.setup\.ts/
    },
    {
      name: "chromium",
      testIgnore: /mobile-web\.spec\.ts/,
      use: { ...devices["Desktop Chrome"] },
      dependencies: ["setup"]
    },
    {
      name: "mobile-chrome",
      testMatch: /mobile-web\.spec\.ts/,
      use: {
        // iPhone 14 profile on Chromium (avoids WebKit install; same viewport/UA).
        ...devices["Desktop Chrome"],
        viewport: devices["iPhone 14"].viewport,
        userAgent: devices["iPhone 14"].userAgent,
        deviceScaleFactor: devices["iPhone 14"].deviceScaleFactor,
        isMobile: true,
        hasTouch: true
      },
      dependencies: ["setup"]
    }
  ]
});
