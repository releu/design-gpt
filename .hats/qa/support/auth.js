import jwt from "jsonwebtoken";

const E2E_JWT_SECRET = "e2e-test-secret-key";

export function createTestToken(user = {}) {
  const payload = {
    sub: user.auth0_id || "auth0|alice123",
    nickname: user.username || "alice",
    email: user.email || "alice@example.com",
    exp: user.exp || Math.floor(Date.now() / 1000) + 3600,
  };
  return jwt.sign(payload, E2E_JWT_SECRET, { algorithm: "HS256" });
}
