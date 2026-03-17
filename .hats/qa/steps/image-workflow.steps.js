const { test, expect } = require("@playwright/test");

const BASE = process.env.BASE_URL || "http://localhost:3000";
const API = `${BASE}/api`;

test.describe("Image Workflow", () => {
  test("image render endpoint returns image bytes", async ({ request }) => {
    const res = await request.get(`${API}/images/render?prompt=modern+office`);
    expect(res.status()).toBe(200);
    expect(res.headers()["content-type"]).toContain("image/");
    expect(res.headers()["access-control-allow-origin"]).toBe("*");
  });

  test("blank prompt returns 400", async ({ request }) => {
    const res = await request.get(`${API}/images/render?prompt=`);
    expect(res.status()).toBe(400);
  });

  test("cache returns same image for repeated queries", async ({ request }) => {
    const res1 = await request.get(`${API}/images/render?prompt=sunset+beach`);
    const res2 = await request.get(`${API}/images/render?prompt=sunset+beach`);
    expect(res1.status()).toBe(200);
    expect(res2.status()).toBe(200);
    const body1 = await res1.body();
    const body2 = await res2.body();
    expect(body1.length).toBe(body2.length);
  });

  test("image search requires authentication", async ({ request }) => {
    const res = await request.get(`${API}/images?q=office`);
    expect(res.status()).toBe(401);
  });

  test("design preview renders image with background-image", async ({
    page,
  }) => {
    // Login first
    await page.goto(`${BASE}/login`);
    await page.fill('[qa="login-email"]', process.env.E2E_EMAIL || "e2e@test.com");
    await page.fill('[qa="login-password"]', process.env.E2E_PASSWORD || "password");
    await page.click('[qa="login-submit"]');
    await page.waitForURL("**/dashboard**");

    // Navigate to design system with image component
    await page.click('[qa="ds-menu-item"]:has-text("Photo")');
    await page.waitForSelector('[qa="component-preview-frame"]');

    const frame = page.frameLocator('[qa="component-preview-frame"]');
    const imageDiv = frame.locator("div[style*='background-image']");
    await expect(imageDiv).toBeVisible();

    const imgTag = frame.locator("img[style*='object-fit']");
    await expect(imgTag).toHaveCount(0);
  });
});
