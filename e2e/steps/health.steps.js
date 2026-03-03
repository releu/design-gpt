import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { When, Then } = createBdd(test);

When("I send a GET request to {string}", async ({ request, world }, path) => {
  world.response = await request.get(path);
});

Then("the response status should be OK", async ({ world }) => {
  expect(world.response.ok()).toBeTruthy();
});
