import { test as base } from "playwright-bdd";

export const test = base.extend({
  consoleErrors: [
    async ({ page }, use) => {
      const errors = [];
      page.on("console", (msg) => {
        if (msg.type() === "error") errors.push(msg.text());
      });
      await use(errors);
    },
    { auto: true },
  ],

  requestFailures: [
    async ({ page }, use) => {
      const failures = [];
      page.on("response", (response) => {
        if (response.status() >= 500) {
          failures.push(`${response.status()} ${response.url()}`);
        }
      });
      await use(failures);
    },
    { auto: true },
  ],

  world: [
    async ({}, use) => {
      await use({});
    },
    { scope: "test" },
  ],
});
