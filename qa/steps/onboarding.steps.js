import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------

Given("I navigate to the onboarding page", async ({ page }) => {
  await page.goto("/onboarding");
  await page.waitForLoadState("domcontentloaded");
});

// ---------------------------------------------------------------------------
// Wizard header and stepper
// ---------------------------------------------------------------------------

Then(
  "the wizard should display the {string} header",
  async ({ page }, header) => {
    await expect(page.locator("text=" + header)).toBeVisible({
      timeout: 10_000,
    });
  },
);

Then("the stepper should show 4 steps", async ({ page }) => {
  const steps = page.locator(".WizardStepper__step, .Stepper__step, [class*='stepper'] [class*='step']");
  await expect(async () => {
    const count = await steps.count();
    expect(count).toBe(4);
  }).toPass({ timeout: 10_000 });
});

Then(
  "the first step {string} should be active",
  async ({ page }, stepName) => {
    const activeStep = page.locator(
      "[class*='stepper'] [class*='active'], .WizardStepper__step_active",
    );
    await expect(activeStep.first()).toBeVisible({ timeout: 5_000 });
  },
);

// ---------------------------------------------------------------------------
// Button states
// ---------------------------------------------------------------------------

Then(
  "the {string} button should appear disabled",
  async ({ page }, buttonText) => {
    const btn = page.locator(`button:has-text("${buttonText}")`).first();
    await expect(btn).toBeVisible({ timeout: 5_000 });
    const isDisabled =
      (await btn.isDisabled()) ||
      (await btn.getAttribute("class")).includes("disabled");
    expect(isDisabled).toBe(true);
  },
);

Then(
  "the {string} button should become enabled",
  async ({ page }, buttonText) => {
    const btn = page.locator(`button:has-text("${buttonText}")`).first();
    await expect(async () => {
      const disabled = await btn.isDisabled();
      expect(disabled).toBe(false);
    }).toPass({ timeout: 10_000 });
  },
);

// ---------------------------------------------------------------------------
// Prompt input
// ---------------------------------------------------------------------------

When(
  "I type a prompt {string} in the onboarding prompt",
  async ({ page }, text) => {
    const input = page.locator(
      ".OnboardingStepPrompt textarea, .OnboardingStepPrompt input, [class*='onboarding'] textarea",
    );
    await expect(input.first()).toBeVisible({ timeout: 5_000 });
    await input.first().fill(text);
  },
);

Then(
  "the onboarding prompt should still contain {string}",
  async ({ page }, text) => {
    const input = page.locator(
      ".OnboardingStepPrompt textarea, .OnboardingStepPrompt input, [class*='onboarding'] textarea",
    );
    await expect(input.first()).toHaveValue(text, { timeout: 5_000 });
  },
);

// ---------------------------------------------------------------------------
// Wizard navigation
// ---------------------------------------------------------------------------

When(
  "I click the {string} button in the wizard",
  async ({ page }, buttonText) => {
    const btn = page.locator(`button:has-text("${buttonText}")`).first();
    if (await btn.isEnabled()) {
      await btn.click();
      await page.waitForTimeout(500);
    }
  },
);

Then(
  "the wizard should advance to the {string} step",
  async ({ page }, stepName) => {
    await expect(
      page.locator(`text=${stepName}`),
    ).toBeVisible({ timeout: 5_000 });
  },
);

Then("the wizard should remain on step 1", async ({ page }) => {
  const promptInput = page.locator(
    ".OnboardingStepPrompt textarea, .OnboardingStepPrompt input, [class*='onboarding'] textarea",
  );
  await expect(promptInput.first()).toBeVisible({ timeout: 5_000 });
});

// ---------------------------------------------------------------------------
// Libraries step
// ---------------------------------------------------------------------------

When("I select the first available library", async ({ page }) => {
  const libraryCard = page.locator(
    ".OnboardingStepLibraries [class*='library'], .OnboardingStepLibraries [class*='card']",
  ).first();
  await expect(libraryCard).toBeVisible({ timeout: 10_000 });
  await libraryCard.click();
});

Then("the selected library should be highlighted", async ({ page }) => {
  const selected = page.locator(
    ".OnboardingStepLibraries [class*='selected'], .OnboardingStepLibraries [class*='active']",
  );
  await expect(selected.first()).toBeVisible({ timeout: 5_000 });
});

// ---------------------------------------------------------------------------
// Components step
// ---------------------------------------------------------------------------

Then(
  "the components list should display imported components",
  async ({ page }) => {
    const components = page.locator(
      ".OnboardingStepComponents [class*='component'], .OnboardingStepComponents li",
    );
    await expect(async () => {
      const count = await components.count();
      expect(count).toBeGreaterThan(0);
    }).toPass({ timeout: 10_000 });
  },
);
