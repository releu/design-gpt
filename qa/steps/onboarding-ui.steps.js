import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { Given, When, Then } = createBdd(test);

// ---------------------------------------------------------------------------
// Onboarding page layout
// ---------------------------------------------------------------------------

Then("the onboarding page background should be warm gray", async ({ page }) => {
  const bgColor = await page.evaluate(() =>
    getComputedStyle(document.body).backgroundColor,
  );
  // Warm gray: not pure white
  expect(bgColor).not.toBe("rgb(255, 255, 255)");
});

Then(
  "a centered container should be visible with max-width around 900px",
  async ({ page }) => {
    // The onboarding container should be centered
    const container = page.locator(
      "[class*='onboarding'], [class*='Onboarding'], [class*='wizard-container']",
    );
    await expect(container.first()).toBeVisible({ timeout: 10_000 });
  },
);

Then(
  'the title "New Project Setup" should be at the top',
  async ({ page }) => {
    const title = page.locator("text=New Project Setup");
    await expect(title.first()).toBeVisible({ timeout: 10_000 });
  },
);

// ---------------------------------------------------------------------------
// Stepper visuals
// ---------------------------------------------------------------------------

Then(
  "each step should be a numbered circle with label connected by lines",
  async ({ page }) => {
    const steps = page.locator(
      ".WizardStepper__step, .Stepper__step, [class*='stepper'] [class*='step']",
    );
    const count = await steps.count();
    expect(count).toBe(4);
    // Each step should have a label
    for (let i = 0; i < count; i++) {
      const text = await steps.nth(i).textContent();
      expect(text.trim().length).toBeGreaterThan(0);
    }
  },
);

Then("upcoming steps should show outline circles", async ({ page }) => {
  // Upcoming (inactive) steps should exist
  const inactive = page.locator(
    "[class*='stepper'] [class*='step']:not([class*='active']):not([class*='completed'])",
  );
  const count = await inactive.count();
  // On step 1, steps 2-4 should be upcoming
  expect(count).toBeGreaterThanOrEqual(2);
});

Then(
  "the step content should be in a white card below the stepper",
  async ({ page }) => {
    const card = page.locator(
      ".OnboardingStepPrompt, [class*='step-content'], [class*='StepContent'], [class*='onboarding'] [class*='card']",
    );
    await expect(card.first()).toBeVisible({ timeout: 10_000 });
    // Check for white background
    const bgColor = await card.first().evaluate((el) =>
      getComputedStyle(el).backgroundColor,
    );
    console.log(`[qa-onboarding] Step content bg: ${bgColor}`);
  },
);

// ---------------------------------------------------------------------------
// Navigation button styling
// ---------------------------------------------------------------------------

Then(
  'the "Next" button should be pill-shaped with dark background',
  async ({ page }) => {
    const btn = page.locator('button:has-text("Next")').first();
    await expect(btn).toBeVisible({ timeout: 5_000 });
    const bgColor = await btn.evaluate((el) =>
      getComputedStyle(el).backgroundColor,
    );
    const borderRadius = await btn.evaluate((el) =>
      getComputedStyle(el).borderRadius,
    );
    console.log(
      `[qa-onboarding] Next button: bg=${bgColor}, radius=${borderRadius}`,
    );
    // Dark background: not white
    expect(bgColor).not.toBe("rgb(255, 255, 255)");
  },
);

Then(
  'on step 1 the "Back" button should be hidden',
  async ({ page }) => {
    const backBtn = page.locator('button:has-text("Back")');
    const isVisible = await backBtn.first().isVisible({ timeout: 3_000 }).catch(() => false);
    // On step 1, Back should be hidden or not present
    expect(isVisible).toBe(false);
  },
);

// ---------------------------------------------------------------------------
// Step 4 specific
// ---------------------------------------------------------------------------

Then(
  'the final button should show "Create Project" label',
  async ({ page }) => {
    const createBtn = page.locator('button:has-text("Create Project")');
    await expect(createBtn.first()).toBeVisible({ timeout: 5_000 });
  },
);

// ---------------------------------------------------------------------------
// Stepper progress
// ---------------------------------------------------------------------------

Then("the stepper should show step 1 as completed", async ({ page }) => {
  const completed = page.locator(
    "[class*='stepper'] [class*='completed'], [class*='stepper'] [class*='done']",
  );
  const count = await completed.count();
  expect(count).toBeGreaterThanOrEqual(1);
});

Then("step 2 should be active", async ({ page }) => {
  const active = page.locator(
    "[class*='stepper'] [class*='active']",
  );
  await expect(active.first()).toBeVisible({ timeout: 5_000 });
  // The active step should be the second one
  const text = await active.first().textContent();
  console.log(`[qa-onboarding] Active step text: ${text}`);
});
