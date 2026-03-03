import { expect } from "@playwright/test";
import { createBdd } from "playwright-bdd";
import { test } from "../fixtures/test.js";

const { When, Then } = createBdd(test);

When("I send a GET request to {string}", async ({ request, world }, urlPath) => {
  world.response = await request.get(urlPath);
});

Then("the response status should be 200", async ({ world }) => {
  expect(world.response.status()).toBe(200);
});
